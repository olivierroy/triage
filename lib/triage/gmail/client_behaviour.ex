defmodule Triage.Gmail.ClientBehaviour do
  @callback list_messages(String.t(), Keyword.t()) ::
              {:ok, list(map()), String.t() | nil} | {:error, any()}
  @callback get_message(String.t(), String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  @callback get_thread(String.t(), String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  @callback get_labels(String.t(), Keyword.t()) :: {:ok, list(map())} | {:error, any()}
  @callback modify_message(String.t(), String.t(), map(), Keyword.t()) ::
              {:ok, map()} | {:error, any()}
  @callback delete_message(String.t(), String.t(), Keyword.t()) :: :ok | {:error, any()}
  @callback trash_message(String.t(), String.t(), Keyword.t()) :: :ok | {:error, any()}
end
