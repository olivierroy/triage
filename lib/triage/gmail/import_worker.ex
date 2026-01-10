defmodule Triage.Gmail.ImportWorker do
  @moduledoc """
  Oban job worker for async Gmail email import.
  """

  use Oban.Worker, queue: :gmail_import, max_attempts: 3
  require Logger

  alias Triage.EmailAccounts.EmailAccount
  alias Triage.Gmail
  alias Triage.Repo

  @impl true
  def perform(%Oban.Job{args: %{"email_account_id" => email_account_id}}) do
    email_account = Repo.get(EmailAccount, email_account_id)

    cond do
      is_nil(email_account) ->
        {:error, :email_account_not_found}

      email_account.paused ->
        {:discard, :email_account_paused}

      true ->
        do_import(email_account)
    end
  end

  defp do_import(%EmailAccount{} = email_account) do
    now = DateTime.utc_now()

    case Gmail.import_emails(email_account) do
      {:ok, count} ->
        Gmail.update_email_account(email_account, %{
          last_synced_at: now
        })

        Logger.info("Successfully imported #{count} emails for account #{email_account.id}")
        :ok

      {:error, error} ->
        Logger.error("Failed to import emails for account #{email_account.id}: #{inspect(error)}")
        {:error, error}
    end
  end

  def enqueue_import(%EmailAccount{} = email_account) do
    %{email_account_id: email_account.id}
    |> new(queue: :gmail_import)
    |> Oban.insert()
  end

  def enqueue_import(email_account_id) when is_integer(email_account_id) do
    %{email_account_id: email_account_id}
    |> new(queue: :gmail_import)
    |> Oban.insert()
  end
end
