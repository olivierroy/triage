defmodule Triage.CategoriesTest do
  use Triage.DataCase

  alias Triage.Accounts.Scope
  alias Triage.Categories
  alias Triage.Categories.Category

  import Triage.AccountsFixtures
  import Triage.CategoriesFixtures

  describe "list_categories/1" do
    test "returns categories scoped to the user" do
      scope = Scope.for_user(user_fixture())
      other_scope = Scope.for_user(user_fixture())

      category = category_fixture(scope)
      _other = category_fixture(other_scope)

      assert [%Category{id: id}] = Categories.list_categories(scope)
      assert id == category.id
    end
  end

  describe "create_category/2" do
    test "creates a category with valid data" do
      scope = Scope.for_user(user_fixture())
      attrs = %{name: "Investor Updates", description: "LP updates"}

      assert {:ok, %Category{} = category} = Categories.create_category(scope, attrs)
      assert category.name == "Investor Updates"
      assert category.description == "LP updates"
    end

    test "returns changeset errors for invalid data" do
      scope = Scope.for_user(user_fixture())

      assert {:error, %Ecto.Changeset{} = changeset} =
               Categories.create_category(scope, %{name: "", description: ""})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).description
    end
  end

  describe "update_category/3" do
    test "updates the name and description" do
      scope = Scope.for_user(user_fixture())
      category = category_fixture(scope, %{name: "Ops", description: "Ops"})

      assert {:ok, %Category{} = updated} =
               Categories.update_category(scope, category, %{
                 name: "Investor",
                 description: "LP newsletters"
               })

      assert updated.name == "Investor"
      assert updated.description == "LP newsletters"
    end

    test "returns errors with invalid data" do
      scope = Scope.for_user(user_fixture())
      category = category_fixture(scope)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Categories.update_category(scope, category, %{name: "", description: ""})

      assert "can't be blank" in errors_on(changeset).name
    end
  end
end
