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

  def evaluate_email(%Scope{user: %{id: _user_id}} = scope, email_attrs) do
    rules = list_email_rules(scope)

    Enum.find_value(rules, fn rule ->
      if matches_rule?(rule, email_attrs) do
        %{action: rule.action, archive: rule.archive}
      end
    end)
  end

  def evaluate_email(_scope, _email_attrs), do: nil

  defp matches_rule?(%EmailRule{} = rule, email_attrs) do
    matches_sender?(rule, email_attrs) or
      matches_subject?(rule, email_attrs) or
      matches_body?(rule, email_attrs)
  end

  defp matches_sender?(%EmailRule{match_senders: senders}, _email_attrs)
       when senders == [],
       do: false

  defp matches_sender?(%EmailRule{match_senders: senders}, %{from: from}) do
    Enum.any?(senders, fn sender ->
      from =~ sender
    end)
  end

  defp matches_subject?(%EmailRule{match_subject_keywords: keywords}, _email_attrs)
       when keywords == [],
       do: false

  defp matches_subject?(%EmailRule{match_subject_keywords: keywords}, %{subject: subject}) do
    email_text = String.downcase(subject || "")

    Enum.any?(keywords, fn keyword ->
      String.contains?(email_text, String.downcase(keyword))
    end)
  end

  defp matches_body?(%EmailRule{match_body_keywords: keywords}, _email_attrs)
       when keywords == [],
       do: false

  defp matches_body?(%EmailRule{match_body_keywords: keywords}, email_attrs) do
    body_text = email_attrs.body_text || email_attrs.snippet || ""

    email_text = String.downcase(body_text)

    Enum.any?(keywords, fn keyword ->
      String.contains?(email_text, String.downcase(keyword))
    end)
  end
end
