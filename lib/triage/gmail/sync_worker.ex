defmodule Triage.Gmail.SyncWorker do
  @moduledoc """
  Oban job worker for periodic Gmail email sync.
  """

  use Oban.Worker, queue: :gmail_sync, max_attempts: 3
  require Logger

  import Ecto.Query, warn: false

  alias Triage.EmailAccounts.EmailAccount
  alias Triage.Gmail.ImportWorker
  alias Triage.Repo

  @impl true
  def perform(%Oban.Job{}) do
    accounts_to_sync = get_active_accounts()

    Logger.info("Syncing #{length(accounts_to_sync)} email accounts")

    Enum.each(accounts_to_sync, fn account ->
      ImportWorker.enqueue_import(account)
    end)

    :ok
  end

  defp get_active_accounts do
    EmailAccount
    |> where([ea], ea.paused == false)
    |> Repo.all()
  end
end
