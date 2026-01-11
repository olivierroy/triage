defmodule Triage.Gmail.AIBehaviour do
  @callback categorize_and_summarize(map(), list(map())) :: {:ok, map()} | {:error, any()}
  @typedoc """
  Structured response returned by the AI unsubscribe flow.
  """
  @type unsubscribe_result :: %{
          required(:unsubscribe_url) => String.t(),
          required(:status) => :success | :failed,
          required(:message) => String.t()
        }

  @callback unsubscribe_from_email(map()) :: {:ok, unsubscribe_result()} | {:error, any()}
end
