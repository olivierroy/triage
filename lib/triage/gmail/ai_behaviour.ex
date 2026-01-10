defmodule Triage.Gmail.AIBehaviour do
  @callback categorize_and_summarize(map(), list(map())) :: {:ok, map()} | {:error, any()}
end
