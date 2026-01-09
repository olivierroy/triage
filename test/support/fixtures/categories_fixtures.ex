defmodule Triage.CategoriesFixtures do
  @moduledoc """
  This module defines test helpers for creating categories.
  """

  alias Triage.Accounts.Scope
  alias Triage.Categories

  import Triage.AccountsFixtures

  def category_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Category #{System.unique_integer([:positive])}",
      description: "Summaries for #{System.unique_integer([:positive])}"
    })
  end

  def category_fixture(scope \\ default_scope(), attrs \\ %{}) do
    attrs = category_attrs(attrs)
    {:ok, category} = Categories.create_category(scope, attrs)
    category
  end

  defp default_scope do
    user_fixture()
    |> Scope.for_user()
  end
end
