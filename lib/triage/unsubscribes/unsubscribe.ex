defmodule Triage.Unsubscribes.Unsubscribe do
  use Ecto.Schema
  import Ecto.Changeset

  schema "unsubscribes" do
    field :status, Ecto.Enum,
      values: [:success, :failed],
      default: :success

    field :unsubscribe_url, :string
    field :error_message, :string
    field :confirmed_message, :string
    field :page_content, :string
    field :flow_type, :string
    field :attempted_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :from_email, :string

    belongs_to :user, Triage.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(unsubscribe, attrs) do
    unsubscribe
    |> cast(attrs, [
      :user_id,
      :status,
      :unsubscribe_url,
      :error_message,
      :confirmed_message,
      :page_content,
      :flow_type,
      :attempted_at,
      :completed_at,
      :from_email
    ])
    |> validate_required([:user_id, :unsubscribe_url])
    |> foreign_key_constraint(:user)
  end
end
