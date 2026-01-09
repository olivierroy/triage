defmodule Triage.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset

  alias Triage.Accounts.User

  schema "categories" do
    field :name, :string
    field :description, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> validate_length(:name, max: 160)
    |> validate_length(:description, max: 5_000)
    |> unique_constraint(:name, name: :categories_user_id_name_index)
  end
end
