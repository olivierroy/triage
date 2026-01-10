defmodule TriageWeb.EmailAccountControllerTest do
  use TriageWeb.ConnCase

  import Triage.GmailFixtures

  setup :register_and_log_in_user

  describe "index email accounts" do
    test "lists all accounts for the user", %{conn: conn, user: user} do
      email_account = email_account_fixture(%{user_id: user.id})
      conn = get(conn, ~p"/email_accounts")
      assert html_response(conn, 200) =~ "Connected Email Accounts"
      assert html_response(conn, 200) =~ email_account.email
    end
  end

  describe "edit email account" do
    test "renders settings form", %{conn: conn, user: user} do
      email_account = email_account_fixture(%{user_id: user.id})
      conn = get(conn, ~p"/email_accounts/#{email_account}/edit")
      assert html_response(conn, 200) =~ "Edit #{email_account.email} Settings"
      assert html_response(conn, 200) =~ "Auto Archive Emails"
      assert html_response(conn, 200) =~ "Paused"
    end
  end

  describe "update email account" do
    test "updates emails account settings and redirects", %{conn: conn, user: user} do
      email_account =
        email_account_fixture(%{user_id: user.id, archive_emails: true, paused: false})

      conn =
        put(conn, ~p"/email_accounts/#{email_account}",
          email_account: %{archive_emails: "false", paused: "true"}
        )

      assert redirected_to(conn) == ~p"/email_accounts/#{email_account}/edit"

      scope = Triage.Accounts.Scope.for_user(user)
      updated_account = Triage.Gmail.get_email_account!(scope, email_account.id)
      refute updated_account.archive_emails
      assert updated_account.paused
    end
  end
end
