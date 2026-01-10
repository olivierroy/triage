defmodule Triage.Gmail.AI do
  @moduledoc """
  AI service for email categorization and summarization using LangChain and Gemini.
  """

  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias LangChain.Message
  alias LangChain.Function

  @model "gemini-2.5-flash"

  def categorize_and_summarize(email_attrs, categories) do
    # Define the structured output function
    categorize_fn =
      Function.new!(%{
        name: "save_categorization",
        description: "Save the categorization and summary of an email.",
        function: fn _args, _context -> {:ok, "Success"} end,
        parameters_schema: %{
          type: "object",
          properties: %{
            category_id: %{
              type: "string",
              description: "The ID of the category that best fits the email. Use 'none' if no category fits well.",
              enum: Enum.map(categories, &to_string(&1.id)) ++ ["none"]
            },
            summary: %{
              type: "string",
              description: "A concise, 1-2 sentence summary of the email content."
            }
          },
          required: ["category_id", "summary"]
        }
      })

    # Prepare the prompt
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
    3. Provide a very concise summary (1-2 sentences) that highlights the most important action item or information.
    4. You may think through your reasoning, but you MUST call the `save_categorization` function as your final act.
    5. MANDATORY: Your output MUST contain a call to `save_categorization`. Do not just provide text.
    """

    user_prompt = """
    Subject: #{email_attrs[:subject] || "(No Subject)"}
    From: #{email_attrs[:from]}
    Content: #{email_attrs[:snippet]}
    """

    require Logger

    # Run the chain
    model = ChatGoogleAI.new!(%{
      model: @model,
      api_key: System.get_env("GOOGLE_API_KEY"),
      temperature: 0
    })

    case LLMChain.new!(%{llm: model})
         |> LLMChain.add_tools(categorize_fn)
         |> LLMChain.add_messages([
           Message.new_system!(system_prompt),
           Message.new_user!(user_prompt)
         ])
         |> LLMChain.run(mode: :while_needs_response) do
      {:ok, updated_chain} ->
        # Look for the tool call in the message history
        tool_call =
          Enum.find_value(Enum.reverse(updated_chain.messages), fn
            %Message{role: :assistant, tool_calls: [tc | _]} -> tc
            _ -> nil
          end)

        case tool_call do
          %LangChain.Message.ToolCall{arguments: args} ->
            result =
              case args do
                %{} = map -> map
                json when is_binary(json) -> Jason.decode!(json)
              end

            {:ok, %{
              category_id: if(result["category_id"] == "none", do: nil, else: result["category_id"]),
              summary: result["summary"]
            }}

          _ ->
            Logger.error("AI failed to call tool. Last message: #{inspect(List.last(updated_chain.messages))}")
            {:error, "AI failed to categorize the email correctly"}
        end

      {:error, _chain, error} ->
        Logger.error("AI Error: #{inspect(error)}")
        {:error, "AI service error: #{inspect(error)}"}
    end
  end
end
