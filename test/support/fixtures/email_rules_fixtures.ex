defmodule Triage.EmailRulesFixtures do
  @moduledoc """
  Helpers for creating email rules in tests.
  """

  alias Triage.Accounts.Scope
  alias Triage.EmailRules

  import Triage.AccountsFixtures

  def email_rule_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Rule #{System.unique_integer([:positive])}",
      action: "process",
      archive: true,
      match_senders: ["alerts@example.com"],
      match_subject_keywords: ["status"],
      match_body_keywords: []
    })
  end

  def email_rule_fixture(scope \\ default_scope(), attrs \\ %{}) do
    attrs = email_rule_attrs(attrs)
    {:ok, rule} = EmailRules.create_email_rule(scope, attrs)
    rule
  end

  defp default_scope do
    user_fixture()
    |> Scope.for_user()
  end
end
