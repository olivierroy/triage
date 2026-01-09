defmodule TriageWeb.PageController do
  use TriageWeb, :controller

  alias Triage.Categories

  def home(conn, _params) do
    case conn.assigns[:current_scope] do
      nil ->
        render(conn, :home)

      current_scope ->
        render(conn, :home_authenticated,
          current_scope: current_scope,
          connected_accounts: connected_accounts(current_scope),
          categories: Categories.list_categories(current_scope)
        )
    end
  end

  defp connected_accounts(current_scope) do
    [
      %{
        email: current_scope.user.email,
        label: "Primary inbox",
        status: "Connected"
      }
    ]
  end
end
