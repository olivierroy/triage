defmodule TriageWeb.PageController do
  use TriageWeb, :controller

  alias Triage.Categories
  alias Triage.Gmail

  def home(conn, _params) do
    case conn.assigns[:current_scope] do
      nil ->
        render(conn, :home)

      current_scope ->
        render(conn, :home_authenticated,
          current_scope: current_scope,
          connected_accounts: Gmail.list_email_accounts(current_scope),
          categories: Categories.list_categories(current_scope),
          email_counts: Gmail.count_emails_by_category(current_scope)
        )
    end
  end
end
