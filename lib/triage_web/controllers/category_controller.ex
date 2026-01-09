defmodule TriageWeb.CategoryController do
  use TriageWeb, :controller

  alias Phoenix.Component
  alias Triage.Categories
  alias Triage.Categories.Category

  def new(conn, _params) do
    current_scope = conn.assigns[:current_scope]
    form = current_scope |> Categories.change_category(%Category{}) |> Component.to_form()

    render(conn, :new, current_scope: current_scope, form: form)
  end

  def create(conn, %{"category" => category_params}) do
    current_scope = conn.assigns[:current_scope]

    case Categories.create_category(current_scope, category_params) do
      {:ok, _category} ->
        conn
        |> put_flash(:info, "Category created")
        |> redirect(to: ~p"/")

      {:error, %Ecto.Changeset{} = changeset} ->
        form = Component.to_form(changeset)
        render(conn, :new, current_scope: current_scope, form: form)
    end
  end

  def create(conn, _params), do: create(conn, %{"category" => %{}})

  def edit(conn, %{"id" => id}) do
    current_scope = conn.assigns[:current_scope]
    category = Categories.get_category!(current_scope, id)
    form = current_scope |> Categories.change_category(category) |> Component.to_form()

    render(conn, :edit, current_scope: current_scope, category: category, form: form)
  end

  def update(conn, %{"id" => id, "category" => category_params}) do
    current_scope = conn.assigns[:current_scope]
    category = Categories.get_category!(current_scope, id)

    case Categories.update_category(current_scope, category, category_params) do
      {:ok, _category} ->
        conn
        |> put_flash(:info, "Category updated")
        |> redirect(to: ~p"/")

      {:error, %Ecto.Changeset{} = changeset} ->
        form = Component.to_form(changeset)
        render(conn, :edit, current_scope: current_scope, category: category, form: form)
    end
  end

  def update(conn, params), do: update(conn, Map.put(params, "category", %{}))
end
