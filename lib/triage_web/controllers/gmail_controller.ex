defmodule TriageWeb.GmailController do
  use TriageWeb, :controller
  require Logger

  alias Triage.Gmail
  alias Triage.Gmail.ImportWorker

  def disconnect(conn, %{"id" => id}) do
    scope = conn.assigns[:current_scope]

    case Gmail.get_email_account!(scope, id) do
      %Triage.EmailAccounts.EmailAccount{} = email_account ->
        Gmail.delete_email_account(email_account)

        conn
        |> put_flash(:info, "Successfully disconnected your Gmail account")
        |> redirect(to: ~p"/")

      error ->
        Logger.error("Failed to disconnect Gmail account: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to disconnect your Gmail account")
        |> redirect(to: ~p"/")
    end
  end

  def import(conn, %{"id" => id}) do
    scope = conn.assigns[:current_scope]

    case Gmail.get_email_account!(scope, id) do
      %Triage.EmailAccounts.EmailAccount{} = email_account ->
        ImportWorker.enqueue_import(email_account)

        conn
        |> put_flash(:info, "Import started. Your emails will be imported in the background.")
        |> redirect(to: ~p"/")

      error ->
        Logger.error("Failed to import emails: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to start email import")
        |> redirect(to: ~p"/")
    end
  end
end
