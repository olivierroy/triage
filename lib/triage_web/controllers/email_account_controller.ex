defmodule TriageWeb.EmailAccountController do
  use TriageWeb, :controller

  alias Triage.Gmail

  def index(conn, _params) do
    email_accounts = Gmail.list_email_accounts(conn.assigns.current_scope)
    render(conn, :index, email_accounts: email_accounts)
  end

  def edit(conn, %{"id" => id}) do
    email_account = Gmail.get_email_account!(conn.assigns.current_scope, id)
    changeset = Triage.EmailAccounts.EmailAccount.settings_changeset(email_account, %{})
    render(conn, :edit, email_account: email_account, changeset: changeset)
  end

  def update(conn, %{"id" => id, "email_account" => email_account_params}) do
    email_account = Gmail.get_email_account!(conn.assigns.current_scope, id)

    case Gmail.update_email_account_settings(email_account, email_account_params) do
      {:ok, _email_account} ->
        conn
        |> put_flash(:info, "Email account updated successfully.")
        |> redirect(to: ~p"/email_accounts")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, email_account: email_account, changeset: changeset)
    end
  end
end
