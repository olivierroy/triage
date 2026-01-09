defmodule Triage.Categories do
  @moduledoc """
  Category management for each user scope.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Triage.Accounts.Scope
  alias Triage.Categories.Category
  alias Triage.Repo

  @doc """
  Lists all categories for the given scope.
  """
  def list_categories(%Scope{user: %{id: user_id}}) do
    Category
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  def list_categories(_), do: []

  @doc """
  Builds a category changeset for the given scope.
  """
  def change_category(%Scope{} = scope, category, attrs \\ %{}) do
    category
    |> set_owner(scope)
    |> Category.changeset(attrs)
  end

  @doc """
  Gets a single category scoped to the user, raising if not found.
  """
  def get_category!(%Scope{user: %{id: user_id}}, id) do
    Repo.get_by!(Category, id: id, user_id: user_id)
  end

  @doc """
  Creates a category from attrs scoped to the user.
  """
  def create_category(%Scope{} = scope, attrs) do
    %Category{}
    |> set_owner(scope)
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category scoped to the user.
  """
  def update_category(%Scope{} = scope, %Category{} = category, attrs) do
    category
    |> set_owner(scope)
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  defp set_owner(%Category{} = category, %Scope{user: %{id: user_id}}) do
    Changeset.change(category, user_id: user_id)
  end

  defp set_owner(%Category{} = category, _scope), do: category
end
