defmodule TriageWeb.EmailControllerTest do
  use TriageWeb.ConnCase, async: true

  import Triage.GmailFixtures
  import Triage.CategoriesFixtures

  setup :register_and_log_in_user

  describe "index" do
    test "lists emails and handles pagination", %{conn: conn, user: user} do
      scope = Triage.Accounts.Scope.for_user(user)
      account = email_account_fixture(scope)

      # Create 55 emails (more than page_size 50)
      for i <- 1..55 do
        email_fixture(scope, account, %{gmail_message_id: "msg_#{i}"})
      end

      conn = get(conn, ~p"/emails")
      response = html_response(conn, 200)
      assert response =~ "Uncategorized Emails"
      assert response =~ "Page 1 of 2"
      assert response =~ "Next"
      refute response =~ "Previous"

      conn = get(conn, ~p"/emails?page=2")
      response = html_response(conn, 200)
      assert response =~ "Page 2 of 2"
      refute response =~ "Next"
      assert response =~ "Previous"
    end

    test "filters by category", %{conn: conn, user: user} do
      scope = Triage.Accounts.Scope.for_user(user)
      account = email_account_fixture(scope)
      category = category_fixture(scope, %{name: "Work"})

      email_fixture(scope, account, %{category_id: category.id, subject: "Work Email"})
      email_fixture(scope, account, %{category_id: nil, subject: "Personal Email"})

      conn = get(conn, ~p"/emails?category_id=#{category.id}")
      response = html_response(conn, 200)
      assert response =~ "Emails in Work"
      assert response =~ "Work Email"
      refute response =~ "Personal Email"

      conn = get(conn, ~p"/emails?category_id=none")
      response = html_response(conn, 200)
      assert response =~ "Uncategorized Emails"
      refute response =~ "Work Email"
      assert response =~ "Personal Email"
    end

    test "deletes email and redirects back to index with params", %{conn: conn, user: user} do
      scope = Triage.Accounts.Scope.for_user(user)
      account = email_account_fixture(scope)
      email = email_fixture(scope, account, %{subject: "Delete Me"})

      # Mock Req globally for the Client
      Application.put_env(:triage, :gmail_client_req_opts, plug: {Req.Test, Triage.Gmail.Client})
      on_exit(fn -> Application.delete_env(:triage, :gmail_client_req_opts) end)

      Req.Test.stub(Triage.Gmail.Client, fn conn ->
        Req.Test.json(conn, %{"id" => email.gmail_message_id})
      end)

      conn = delete(conn, ~p"/emails/#{email}?category_id=none&page=1")
      assert redirected_to(conn) == ~p"/emails?category_id=none&page=1"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Email deleted successfully"

      assert_raise Ecto.NoResultsError, fn ->
        Triage.Gmail.get_email!(scope, email.id)
      end
    end
  end
end
