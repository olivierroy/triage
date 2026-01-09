defmodule Triage.EmailRulesTest do
  use Triage.DataCase

  alias Triage.Accounts.Scope
  alias Triage.EmailRules
  alias Triage.EmailRules.EmailRule

  import Triage.AccountsFixtures
  import Triage.EmailRulesFixtures

  describe "list_email_rules/1" do
    test "returns rules for the scope" do
      scope = Scope.for_user(user_fixture())
      other_scope = Scope.for_user(user_fixture())

      rule = email_rule_fixture(scope)
      _other = email_rule_fixture(other_scope)

      assert [%EmailRule{id: id}] = EmailRules.list_email_rules(scope)
      assert id == rule.id
    end
  end

  describe "create_email_rule/2" do
    test "creates rule with valid data" do
      scope = Scope.for_user(user_fixture())

      attrs = %{
        name: "Skip promos",
        action: "skip",
        archive: false,
        match_senders: ["promos@example.com"],
        match_subject_keywords: ["sale"],
        match_body_keywords: []
      }

      assert {:ok, %EmailRule{} = rule} = EmailRules.create_email_rule(scope, attrs)
      assert rule.name == "Skip promos"
      assert rule.action == "skip"
      refute rule.archive
    end

    test "returns errors when invalid" do
      scope = Scope.for_user(user_fixture())

      assert {:error, %Ecto.Changeset{} = changeset} =
               EmailRules.create_email_rule(scope, %{name: "", action: "oops", archive: nil})

      assert "can't be blank" in errors_on(changeset).name
      assert "is invalid" in errors_on(changeset).action
    end
  end

  describe "update_email_rule/3" do
    test "updates rule" do
      scope = Scope.for_user(user_fixture())
      rule = email_rule_fixture(scope)

      assert {:ok, %EmailRule{} = updated} =
               EmailRules.update_email_rule(scope, rule, %{name: "Filtered"})

      assert updated.name == "Filtered"
    end

    test "returns errors on invalid update" do
      scope = Scope.for_user(user_fixture())
      rule = email_rule_fixture(scope)

      assert {:error, %Ecto.Changeset{} = changeset} =
               EmailRules.update_email_rule(scope, rule, %{action: "invalid"})

      assert "is invalid" in errors_on(changeset).action
    end
  end

  describe "delete_email_rule/2" do
    test "removes the rule" do
      scope = Scope.for_user(user_fixture())
      rule = email_rule_fixture(scope)

      assert {:ok, %EmailRule{}} = EmailRules.delete_email_rule(scope, rule)
      assert [] == EmailRules.list_email_rules(scope)
    end
  end
end
