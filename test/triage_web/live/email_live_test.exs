defmodule TriageWeb.EmailLiveTest do
  use TriageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Triage.AccountsFixtures
  import Triage.GmailFixtures
  import Triage.CategoriesFixtures

  alias Triage.Accounts.Scope

  setup %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)
    account = email_account_fixture(scope)
    conn = conn |> log_in_user(user)
    {:ok, conn: conn, user: user, scope: scope, account: account}
  end

  test "renders inbox and emails", %{conn: conn, scope: scope, account: account} do
    _email = email_fixture(scope, account, %{subject: "Hello World"})

    {:ok, _view, html} = live(conn, ~p"/emails")

    assert html =~ "Your Email Inbox"
    assert html =~ "Hello World"
  end

  test "filters by category", %{conn: conn, scope: scope, account: account} do
    category = category_fixture(scope, %{name: "Important"})

    _email1 =
      email_fixture(scope, account, %{subject: "Important Email", category_id: category.id})

    _email2 = email_fixture(scope, account, %{subject: "Spam", category_id: nil})

    {:ok, view, _html} = live(conn, ~p"/emails?category_id=#{category.id}")

    assert render(view) =~ "Emails in Important"
    assert render(view) =~ "Important Email"
    refute render(view) =~ "Spam"
  end

  test "filters by uncategorized", %{conn: conn, scope: scope, account: account} do
    category = category_fixture(scope, %{name: "Important"})

    _email1 =
      email_fixture(scope, account, %{subject: "Important Email", category_id: category.id})

    _email2 = email_fixture(scope, account, %{subject: "Uncategorized Email", category_id: nil})

    {:ok, view, _html} = live(conn, ~p"/emails?category_id=none")

    assert render(view) =~ "Uncategorized Emails"
    refute render(view) =~ "Important Email"
    assert render(view) =~ "Uncategorized Email"
  end

  test "opens email modal when clicking subject", %{conn: conn, scope: scope, account: account} do
    _email = email_fixture(scope, account, %{subject: "Click Me", body_text: "Secret content"})

    {:ok, view, _html} = live(conn, ~p"/emails")

    view
    |> element("button", "Click Me")
    |> render_click()

    assert render(view) =~ "Secret content"
    assert render(view) =~ "Delete Email"
  end

  test "pagination works", %{conn: conn, scope: scope, account: account} do
    # Create 55 emails (page size is 50)
    for i <- 1..55 do
      email_fixture(scope, account, %{subject: "Email #{i}"})
    end

    {:ok, view, _html} = live(conn, ~p"/emails")

    assert render(view) =~ "Page 1 of 2"
    assert render(view) =~ "Next"

    view
    |> element("a", "Next")
    |> render_click()

    assert_patched(view, ~p"/emails?#{[category_id: nil, page: 2]}")
    assert render(view) =~ "Page 2 of 2"
    assert render(view) =~ "Previous"
  end
end
