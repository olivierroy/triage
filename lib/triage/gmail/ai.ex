defmodule Triage.Gmail.AI do
  @behaviour Triage.Gmail.AIBehaviour
  @moduledoc """
  AI service for email categorization and summarization using LangChain and Gemini.
  Uses function calling for reliable structured output.
  """

  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias LangChain.Message
  alias LangChain.Message.ContentPart
  alias LangChain.Message.ToolResult
  alias LangChain.MessageProcessors.JsonProcessor
  alias Triage.MCPTools
  require Logger

  @models ["gemini-2.5-flash-lite"]
  @categorize_response_schema %{
    "type" => "OBJECT",
    "required" => ["category_id", "summary"],
    "properties" => %{
      "category_id" => %{
        "type" => "STRING",
        "nullable" => true,
        "description" =>
          "The ID of the matching category. Return null if no category fits (do not invent IDs)."
      },
      "summary" => %{
        "type" => "STRING",
        "description" =>
          "A concise 3-4 sentence summary highlighting the key action item or information from the email."
      }
    }
  }
  @unsubscribe_response_schema %{
    "type" => "OBJECT",
    "required" => ["status"],
    "properties" => %{
      "status" => %{
        "type" => "STRING",
        "enum" => ["found", "none"],
        "description" => "Whether an unsubscribe URL was found ('found') or absent ('none')."
      },
      "unsubscribe_url" => %{
        "type" => "STRING",
        "nullable" => true,
        "description" =>
          "The exact URL the recipient must visit to unsubscribe, opt-out, or manage preferences. Required when status is 'found'."
      },
      "note" => %{
        "type" => "STRING",
        "nullable" => true,
        "description" => "Optional explanation when status is 'none'"
      }
    }
  }
  @unsubscribe_completion_schema %{
    "type" => "OBJECT",
    "required" => ["success", "message"],
    "properties" => %{
      "success" => %{
        "type" => "BOOLEAN",
        "description" => "Set to true only when the unsubscribe process is fully completed"
      },
      "message" => %{
        "type" => "STRING",
        "description" =>
          "Exact confirmation or error text taken from the unsubscribe web page (no paraphrasing)"
      }
    }
  }

  @impl true
  def categorize_and_summarize(email_attrs, categories) do
    category_list =
      categories
      |> Enum.map(fn c -> "- #{c.name} (ID: #{c.id}): #{c.description}" end)
      |> Enum.join("\n")

    system_prompt = """
    You are an expert personal assistant. Your task is to categorize and summarize incoming emails.

    Available Categories:
    #{category_list}

    Instructions:
    1. Read the email subject and snippet carefully.
    2. Choose the best matching category from the list above. If none fit well, use 'none'.
    3. Provide a very concise summary (3-4 sentences) that highlights the most important action item or information.
    """

    user_prompt = """
    Subject: #{email_attrs[:subject] || "(No Subject)"}
    From: #{email_attrs[:from]}
    Content: #{email_attrs[:snippet]}
    """

    selected_model = Enum.random(@models)
    Logger.info("Using AI model: #{selected_model} (Structured Output)")

    model =
      ChatGoogleAI.new!(%{
        model: selected_model,
        api_key: System.get_env("GOOGLE_API_KEY"),
        temperature: 0,
        json_response: true,
        json_schema: @categorize_response_schema
      })

    processors = [JsonProcessor.new!()]

    case LLMChain.new!(%{llm: model, verbose: true})
         |> LLMChain.message_processors(processors)
         |> LLMChain.add_messages([
           Message.new_system!(system_prompt),
           Message.new_user!(user_prompt)
         ])
         |> LLMChain.run(mode: :until_success) do
      {:ok, updated_chain} ->
        with {:ok, result} <- categorize_from_message(updated_chain.last_message) do
          {:ok, result}
        else
          {:error, reason} ->
            Logger.error("AI categorization parse failure: #{inspect(reason)}")
            {:error, "AI failed to categorize the email correctly"}
        end

      {:error, _chain, error} ->
        Logger.error("AI Error: #{inspect(error)}")
        {:error, "AI service error: #{inspect(error)}"}
    end
  end

  @impl true
  def unsubscribe_from_email(email_attrs) do
    system_prompt = """
    You are an expert at analyzing emails to find unsubscribe URLs.
    """

    base_user_prompt = """
    Subject: #{email_attrs[:subject] || "(No Subject)"}
    From: #{email_attrs[:from]}

    Email HTML content:
    #{email_attrs[:body_html] || email_attrs[:body_text] || ""}

    Please extract the unsubscribe URL from the email content. Look for links with text like: unsubscribe, opt-out, manage preferences, manage subscriptions, etc.

    If no unsubscribe option exists, respond with status "none" and leave unsubscribe_url blank.
    """

    selected_model = Enum.random(@models)
    Logger.info("Using AI model: #{selected_model} to extract unsubscribe URL")

    model =
      ChatGoogleAI.new!(%{
        model: selected_model,
        api_key: System.get_env("GOOGLE_API_KEY"),
        temperature: 0,
        json_response: true,
        json_schema: @unsubscribe_response_schema
      })

    processors = [JsonProcessor.new!()]

    case LLMChain.new!(%{llm: model, verbose: true})
         |> LLMChain.message_processors(processors)
         |> LLMChain.add_messages([
           Message.new_system!(system_prompt),
           Message.new_user!(base_user_prompt)
         ])
         |> LLMChain.run(mode: :until_success) do
      {:ok, updated_chain} ->
        case extract_unsubscribe_from_message(updated_chain.last_message) do
          {:ok, %{status: :found, unsubscribe_url: unsubscribe_url}} ->
            if Process.whereis(Triage.PlaywrightMCP) do
              Logger.info("Found unsubscribe URL, attempting to navigate: #{unsubscribe_url}")
              complete_unsubscribe(unsubscribe_url, email_attrs, email_attrs[:receiver_email])
            else
              Logger.warning("Playwright MCP not available, returning URL for manual action")

              {:ok,
               %{
                 unsubscribe_url: unsubscribe_url,
                 status: :failed,
                 message: "Unsubscribe URL found but requires manual action"
               }}
            end

          {:ok, %{status: :not_found, note: note}} ->
            {:ok,
             %{
               unsubscribe_url: nil,
               status: :not_found,
               message: note || "No unsubscribe link was detected in this email"
             }}

          {:error, _reason} ->
            {:error, "Failed to extract unsubscribe URL from email"}
        end

      {:error, _chain, error} ->
        Logger.error("AI Error extracting unsubscribe URL: #{inspect(error)}")
        {:error, "Failed to extract unsubscribe URL: #{inspect(error)}"}
    end
  end

  defp categorize_from_message(%Message{} = message) do
    with {:ok, data} <- resolve_processed_content(message),
         {:ok, summary} <- fetch_summary(data),
         {:ok, category_id} <- fetch_category_id(data) do
      {:ok, %{summary: summary, category_id: category_id}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_summary(%{"summary" => summary}) when is_binary(summary) do
    trimmed = String.trim(summary)

    if trimmed == "" do
      {:error, :missing_summary}
    else
      {:ok, trimmed}
    end
  end

  defp fetch_summary(_), do: {:error, :missing_summary}

  defp fetch_category_id(%{"category_id" => category_id}) do
    cond do
      is_nil(category_id) ->
        {:ok, nil}

      is_binary(category_id) ->
        normalized =
          category_id
          |> String.trim()
          |> normalize_none()

        {:ok, normalized}

      true ->
        {:error, {:invalid_category_id, category_id}}
    end
  end

  defp fetch_category_id(_), do: {:error, :missing_category_id}

  defp normalize_none(""), do: nil

  defp normalize_none(value) when is_binary(value) do
    if String.downcase(value) == "none", do: nil, else: value
  end

  defp normalize_none(_other), do: nil

  defp complete_unsubscribe(unsubscribe_url, _email_attrs, receiver_email) do
    mcp_functions = MCPTools.to_functions()

    schema_json = Jason.encode!(@unsubscribe_completion_schema)

    system_prompt = """
    You are an expert at navigating web pages to complete unsubscribe processes.
    Always return a final JSON object with the exact confirmation text you saw
    on the website. It must conform to this schema:

    #{schema_json}

    Do not add commentary before or after the JSON.
    """

    user_prompt = """
    Navigate to the unsubscribe URL and complete the unsubscribe process.
    URL: #{unsubscribe_url}
    Email account to unsubscribe: #{receiver_email}

    Please:
    1. Navigate to that link using browser tools and complete the captcha if you need to
    2. Complete the unsubscribe process (click unsubscribe/opt-out buttons, confirm prompts)
    3. If prompted for an email address, use: #{receiver_email}
    4. Make sure to fully submit the unsubscribe request and reach a confirmation page
    5. Return the JSON response described in the system prompt with the exact confirmation copy from the page
    6. If anything fails, set success to false and message to the exact error text shown
    """

    selected_model = "gemini-2.5-pro"
    Logger.info("Using AI model: #{selected_model} for unsubscribe (with Playwright MCP)")

    model =
      ChatGoogleAI.new!(%{
        model: selected_model,
        api_key: System.get_env("GOOGLE_API_KEY"),
        temperature: 0
      })

    all_tools = mcp_functions

    case LLMChain.new!(%{llm: model, verbose: true})
         |> LLMChain.add_messages([
           Message.new_system!(system_prompt),
           Message.new_user!(user_prompt)
         ])
         |> LLMChain.add_tools(all_tools)
         |> LLMChain.run(mode: :while_needs_response) do
      {:ok, updated_chain} ->
        case parse_unsubscribe_completion(updated_chain) do
          {:ok, %{success: true, message: message}} ->
            Logger.info("Successfully completed unsubscribe flow")

            {:ok,
             %{
               unsubscribe_url: unsubscribe_url,
               status: :success,
               message: message
             }}

          {:ok, %{success: false, message: message}} ->
            failure = failed_unsubscribe_result(unsubscribe_url, message)
            Logger.error("Unsubscribe automation reported failure: #{failure.message}")
            {:ok, failure}

          {:error, reason} ->
            message_or_reason =
              case unsubscribe_failure_reason(updated_chain) do
                fallback when is_binary(fallback) -> fallback
                _ -> reason
              end

            failure = failed_unsubscribe_result(unsubscribe_url, message_or_reason)
            Logger.error("Unsubscribe automation did not confirm success: #{failure.message}")
            {:ok, failure}
        end

      {:error, _chain, error} ->
        Logger.error("Unsubscribe AI Error: #{inspect(error)}")

        failure =
          failed_unsubscribe_result(
            unsubscribe_url,
            "Failed to complete unsubscribe: #{inspect(error)}"
          )

        {:ok, failure}
    end
  end

  defp unsubscribe_failure_reason(%LLMChain{} = chain) do
    case chain |> tool_results_from_chain() |> Enum.reverse() |> Enum.find(& &1.is_error) do
      %ToolResult{content: content} when is_binary(content) and content != "" ->
        "Unsubscribe automation failed: #{content}"

      _ ->
        "Unsubscribe automation failed before confirmation"
    end
  end

  defp failed_unsubscribe_result(unsubscribe_url, message) do
    formatted_message = format_failure_message(message)

    %{
      unsubscribe_url: unsubscribe_url,
      status: :failed,
      message: formatted_message
    }
  end

  defp format_failure_message(message) when is_binary(message) do
    case String.trim(message) do
      "" -> "Unsubscribe automation failed without a reason"
      trimmed -> trimmed
    end
  end

  defp format_failure_message(message) do
    "Unsubscribe automation failed: #{inspect(message)}"
  end

  defp parse_unsubscribe_completion(%LLMChain{} = chain) do
    with {:ok, message} <- final_assistant_message(chain),
         {:ok, data} <- resolve_processed_content(message),
         {:ok, payload} <- to_unsubscribe_completion_payload(data) do
      {:ok, payload}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp final_assistant_message(%LLMChain{} = chain) do
    chain.messages
    |> Enum.reverse()
    |> Enum.find(&match?(%Message{role: :assistant}, &1))
    |> case do
      nil -> {:error, "Unsubscribe automation did not return a final response"}
      message -> {:ok, message}
    end
  end

  defp to_unsubscribe_completion_payload(%{"success" => success, "message" => message})
       when is_boolean(success) and is_binary(message) do
    trimmed = String.trim(message)

    if trimmed == "" do
      {:error, "Unsubscribe automation returned an empty message"}
    else
      {:ok, %{success: success, message: trimmed}}
    end
  end

  defp to_unsubscribe_completion_payload(_other) do
    {:error, "Invalid unsubscribe completion payload"}
  end

  defp tool_results_from_chain(%LLMChain{} = chain) do
    chain.messages
    |> Enum.filter(&match?(%Message{role: :tool}, &1))
    |> Enum.flat_map(&(&1.tool_results || []))
  end

  defp extract_unsubscribe_from_message(%Message{} = message) do
    with {:ok, data} <- resolve_processed_content(message),
         {:ok, parsed} <- to_unsubscribe_result(data) do
      {:ok, parsed}
    else
      {:error, reason} ->
        Logger.error("Failed to parse unsubscribe response: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp resolve_processed_content(%Message{processed_content: %{} = content}), do: {:ok, content}

  defp resolve_processed_content(%Message{} = message) do
    case ContentPart.content_to_string(message.content) do
      nil -> {:error, :empty_content}
      json -> Jason.decode(json)
    end
  end

  defp to_unsubscribe_result(%{"status" => "found"} = data) do
    case data["unsubscribe_url"] do
      url when is_binary(url) ->
        trimmed = String.trim(url)

        if trimmed == "" do
          {:error, :missing_unsubscribe_url}
        else
          {:ok, %{status: :found, unsubscribe_url: trimmed, note: data["note"]}}
        end

      other ->
        {:error, {:missing_unsubscribe_url, other}}
    end
  end

  defp to_unsubscribe_result(%{"status" => "none"} = data) do
    {:ok, %{status: :not_found, note: data["note"]}}
  end

  defp to_unsubscribe_result(%{"status" => other}), do: {:error, {:invalid_status, other}}
  defp to_unsubscribe_result(_), do: {:error, :missing_status}
end
