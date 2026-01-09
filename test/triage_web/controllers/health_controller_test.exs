defmodule TriageWeb.HealthControllerTest do
  use TriageWeb.ConnCase, async: true

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert %{"status" => "ok"} = json_response(conn, 200)
  end
end
