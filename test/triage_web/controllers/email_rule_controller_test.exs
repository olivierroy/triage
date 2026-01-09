defmodule TriageWeb.EmailRuleControllerTest do
  use TriageWeb.ConnCase

  import Triage.EmailRulesFixtures

  setup :register_and_log_in_user

  test "GET /email_rules lists rules", %{conn: conn, scope: scope} do
    rule = email_rule_fixture(scope, %{name: "Skip promos"})

    conn = get(conn, ~p"/email_rules")
    response = html_response(conn, 200)
    assert response =~ "Email rules"
    assert response =~ rule.name
  end

  test "GET /email_rules/new renders form", %{conn: conn} do
    conn = get(conn, ~p"/email_rules/new")
    assert html_response(conn, 200) =~ "New rule"
  end

  test "POST /email_rules creates rule", %{conn: conn} do
    conn =
      post(conn, ~p"/email_rules", %{
        "email_rule" => %{
          "name" => "Skip promos",
          "action" => "skip",
          "archive" => "false",
          "match_senders" => "promos@example.com"
        }
      })

    assert redirected_to(conn) == ~p"/email_rules"
  end

  test "GET /email_rules/:id/edit renders form", %{conn: conn, scope: scope} do
    rule = email_rule_fixture(scope)
    conn = get(conn, ~p"/email_rules/#{rule}/edit")
    assert html_response(conn, 200) =~ "Edit rule"
  end

  test "PATCH /email_rules/:id updates rule", %{conn: conn, scope: scope} do
    rule = email_rule_fixture(scope)

    conn =
      patch(conn, ~p"/email_rules/#{rule}", %{
        "email_rule" => %{"name" => "Alerts"}
      })

    assert redirected_to(conn) == ~p"/email_rules"
  end

  test "DELETE /email_rules/:id removes rule", %{conn: conn, scope: scope} do
    rule = email_rule_fixture(scope)

    conn = delete(conn, ~p"/email_rules/#{rule}")
    assert redirected_to(conn) == ~p"/email_rules"
  end

  test "invalid create rerenders form", %{conn: conn} do
    conn = post(conn, ~p"/email_rules", %{"email_rule" => %{"name" => ""}})
    assert html_response(conn, 200) =~ "New rule"
  end

  test "invalid update rerenders form", %{conn: conn, scope: scope} do
    rule = email_rule_fixture(scope)
    conn = patch(conn, ~p"/email_rules/#{rule}", %{"email_rule" => %{"action" => "bad"}})
    assert html_response(conn, 200) =~ "Edit rule"
  end
end
