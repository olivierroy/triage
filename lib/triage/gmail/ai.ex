defmodule Triage.Gmail.AI do
  @behaviour Triage.Gmail.AIBehaviour
  @moduledoc """
  AI service for email categorization and summarization using LangChain and Gemini.
  Uses JSON mode for reliable structured output.
  """

  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatGoogleAI
  alias LangChain.Message
  require Logger

  @models ["gemini-2.0-flash", "gemini-2.0-flash-lite"]

  @impl true
  def categorize_and_summarize(email_attrs, categories) do
    # Prepare the prompt
    category_list =
      categories
      |> Enum.map(fn c -> "- #{c.name} (ID: #{c.id}): #{c.description}" end)
      |> Enum.join("\n")

    system_prompt = """
    You are an expert personal assistant. Your task is to categorize and summarize incoming emails.
    You MUST respond with a valid JSON object.

    Available Categories:
    #{category_list}

    Instructions:
    1. Read the email subject and snippet carefully.
    2. Choose the best matching category from the list above. If none fit well, use 'none'.
    3. Provide a very concise summary (3-4 sentences) that highlights the most important action item or information.

    Required JSON structure:
    {
      "category_id": "string or 'none'",
      "summary": "string"
    }
    """

    user_prompt = """
    Subject: #{email_attrs[:subject] || "(No Subject)"}
    From: #{email_attrs[:from]}
    Content: #{email_attrs[:snippet]}
    """

    # Select a random model to efficiently use free tier
    selected_model = Enum.random(@models)
    Logger.info("Using AI model: #{selected_model} (JSON Mode)")

    # Run the chain
    model =
      ChatGoogleAI.new!(%{
        model: selected_model,
        api_key: System.get_env("GOOGLE_API_KEY"),
        temperature: 0,
        config: %{
          response_mime_type: "application/json"
        }
      })

    case LLMChain.new!(%{llm: model})
         |> LLMChain.add_messages([
           Message.new_system!(system_prompt),
           Message.new_user!(user_prompt)
         ])
         |> LLMChain.run() do
      {:ok, updated_chain} ->
        last_message = List.last(updated_chain.messages)

        case Jason.decode(last_message.content) do
          {:ok, result} ->
            {:ok,
             %{
               category_id:
                 if(result["category_id"] == "none" or is_nil(result["category_id"]),
                   do: nil,
                   else: result["category_id"]
                 ),
               summary: result["summary"]
             }}

          {:error, _} ->
            Logger.error(
              "AI failed to return valid JSON. Content: #{inspect(last_message.content)}"
            )

            {:error, "AI failed to categorize the email correctly"}
        end

      {:error, _chain, error} ->
        Logger.error("AI Error: #{inspect(error)}")
        {:error, "AI service error: #{inspect(error)}"}
    end
  end
end
