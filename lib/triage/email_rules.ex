defmodule Triage.EmailRules do
  @moduledoc """
  Manages user-defined email rules controlling processing/archiving.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Triage.Accounts.Scope
  alias Triage.EmailRules.EmailRule
  alias Triage.Repo

  def list_email_rules(%Scope{user: %{id: user_id}}) do
    EmailRule
    |> where([r], r.user_id == ^user_id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  def list_email_rules(_), do: []

  def get_email_rule!(%Scope{user: %{id: user_id}}, id) do
    Repo.get_by!(EmailRule, id: id, user_id: user_id)
  end

  def change_email_rule(%Scope{} = scope, %EmailRule{} = email_rule, attrs \\ %{}) do
    email_rule
    |> set_owner(scope)
    |> EmailRule.changeset(attrs)
  end

  def create_email_rule(%Scope{} = scope, attrs) do
    %EmailRule{}
    |> set_owner(scope)
    |> EmailRule.changeset(attrs)
    |> Repo.insert()
  end

  def update_email_rule(%Scope{} = scope, %EmailRule{} = email_rule, attrs) do
    email_rule
    |> set_owner(scope)
    |> EmailRule.changeset(attrs)
    |> Repo.update()
  end

  def delete_email_rule(%Scope{user: %{id: user_id}}, %EmailRule{id: id}) do
    from(r in EmailRule, where: r.id == ^id and r.user_id == ^user_id)
    |> Repo.one!()
    |> Repo.delete()
  end

  defp set_owner(%EmailRule{} = email_rule, %Scope{user: %{id: user_id}}) do
    Changeset.change(email_rule, user_id: user_id)
  end

  defp set_owner(email_rule, _scope), do: email_rule
end
