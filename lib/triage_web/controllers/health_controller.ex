defmodule TriageWeb.HealthController do
  use TriageWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
