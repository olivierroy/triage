defmodule Triage.EmailRules.EmailRule do
  use Ecto.Schema
  import Ecto.Changeset

  alias Triage.Accounts.User

  @array_fields [:match_senders, :match_subject_keywords, :match_body_keywords]

  schema "email_rules" do
    field :name, :string
    field :action, :string, default: "process"
    field :archive, :boolean, default: true
    field :match_senders, {:array, :string}, default: []
    field :match_subject_keywords, {:array, :string}, default: []
    field :match_body_keywords, {:array, :string}, default: []

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @actions ~w(process skip)

  @doc false
  def changeset(email_rule, attrs) do
    attrs = normalize_inputs(attrs)

    email_rule
    |> cast(attrs, [
      :name,
      :action,
      :archive,
      :match_senders,
      :match_subject_keywords,
      :match_body_keywords
    ])
    |> validate_required([:name, :action, :archive])
    |> validate_length(:name, max: 160)
    |> validate_inclusion(:action, @actions)
    |> unique_constraint(:name, name: :email_rules_user_id_name_index)
  end

  defp normalize_inputs(attrs) when is_map(attrs) do
    Enum.reduce(@array_fields, attrs, fn field, acc ->
      Enum.reduce([field, Atom.to_string(field)], acc, fn key, current_acc ->
        case Map.fetch(current_acc, key) do
          {:ok, value} -> Map.put(current_acc, key, normalize_array_value(value))
          :error -> current_acc
        end
      end)
    end)
  end

  defp normalize_inputs(other), do: other

  defp normalize_array_value(nil), do: []

  defp normalize_array_value(value) when is_list(value) do
    value
    |> Enum.map(&normalize_scalar/1)
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp normalize_array_value(value) when is_binary(value) do
    value
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&normalize_scalar/1)
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp normalize_array_value(value), do: value

  defp normalize_scalar(value) when is_binary(value), do: String.trim(value)
  defp normalize_scalar(value), do: value
end
