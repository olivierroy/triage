defmodule TriageWeb.EmailRuleController do
  use TriageWeb, :controller

  alias Phoenix.Component
  alias Triage.EmailRules
  alias Triage.EmailRules.EmailRule

  plug :require_scope

  def index(conn, _params) do
    current_scope = conn.assigns[:current_scope]
    rules = EmailRules.list_email_rules(current_scope)

    render(conn, :index, current_scope: current_scope, rules: rules)
  end

  def new(conn, _params) do
    current_scope = conn.assigns[:current_scope]
    form = current_scope |> EmailRules.change_email_rule(%EmailRule{}) |> Component.to_form()

    render(conn, :new, current_scope: current_scope, form: form)
  end

  def create(conn, %{"email_rule" => params}) do
    current_scope = conn.assigns[:current_scope]

    case EmailRules.create_email_rule(current_scope, params) do
      {:ok, _rule} ->
        conn
        |> put_flash(:info, "Rule created")
        |> redirect(to: ~p"/email_rules")

      {:error, %Ecto.Changeset{} = changeset} ->
        form = Component.to_form(changeset)
        render(conn, :new, current_scope: current_scope, form: form)
    end
  end

  def edit(conn, %{"id" => id}) do
    current_scope = conn.assigns[:current_scope]
    rule = EmailRules.get_email_rule!(current_scope, id)
    form = current_scope |> EmailRules.change_email_rule(rule) |> Component.to_form()

    render(conn, :edit, current_scope: current_scope, email_rule: rule, form: form)
  end

  def update(conn, %{"id" => id, "email_rule" => params}) do
    current_scope = conn.assigns[:current_scope]
    rule = EmailRules.get_email_rule!(current_scope, id)

    case EmailRules.update_email_rule(current_scope, rule, params) do
      {:ok, _rule} ->
        conn
        |> put_flash(:info, "Rule updated")
        |> redirect(to: ~p"/email_rules")

      {:error, %Ecto.Changeset{} = changeset} ->
        form = Component.to_form(changeset)
        render(conn, :edit, current_scope: current_scope, email_rule: rule, form: form)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_scope = conn.assigns[:current_scope]
    rule = EmailRules.get_email_rule!(current_scope, id)
    {:ok, _} = EmailRules.delete_email_rule(current_scope, rule)

    conn
    |> put_flash(:info, "Rule deleted")
    |> redirect(to: ~p"/email_rules")
  end

  defp require_scope(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_flash(:error, "You must be signed in to manage email rules.")
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end
end
