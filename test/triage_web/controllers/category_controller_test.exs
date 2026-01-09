defmodule TriageWeb.CategoryControllerTest do
  use TriageWeb.ConnCase

  import Triage.CategoriesFixtures

  setup :register_and_log_in_user

  test "GET /categories/new renders form", %{conn: conn} do
    conn = get(conn, ~p"/categories/new")
    assert html_response(conn, 200) =~ "New category"
  end

  test "GET /categories/:id/edit renders existing data", %{conn: conn, scope: scope} do
    category = category_fixture(scope, %{name: "Ops", description: "Ops"})

    conn = get(conn, ~p"/categories/#{category}/edit")
    response = html_response(conn, 200)
    assert response =~ "Edit category"
    assert response =~ "Ops"
  end

  test "PATCH /categories/:id updates category", %{conn: conn, scope: scope} do
    category = category_fixture(scope)

    conn =
      patch(conn, ~p"/categories/#{category}", %{
        "category" => %{name: "Investor", description: "LP"}
      })

    assert redirected_to(conn) == ~p"/"
  end

  test "PATCH /categories/:id shows errors on failure", %{conn: conn, scope: scope} do
    category = category_fixture(scope)

    conn =
      patch(conn, ~p"/categories/#{category}", %{
        "category" => %{name: "", description: ""}
      })

    response = html_response(conn, 200)
    assert response =~ "Edit category"
    assert response =~ "can&#39;t be blank"
  end
end
