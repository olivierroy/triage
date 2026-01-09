defmodule TriageWeb.PageControllerTest do
  use TriageWeb.ConnCase

  import Triage.AccountsFixtures
  alias Triage.Accounts.Scope
  alias Triage.Categories

  test "GET / shows marketing site for guests", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Sign in with Google, define categories"
  end

  test "GET / shows multi inbox dashboard for logged in users", %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)
    {:ok, _category} = Categories.create_category(scope, %{name: "Investor", description: "LP"})

    conn = conn |> log_in_user(user) |> get(~p"/")

    response = html_response(conn, 200)
    assert response =~ "Connect other Gmail accounts"
    assert response =~ "Your custom categories"
    assert response =~ "Add new category"
    assert response =~ "Investor"
  end
end
