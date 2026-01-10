defmodule Triage.EmailAccounts.EmailAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ["gmail"]

  schema "email_accounts" do
    field :provider, :string
    field :email, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :token_type, :string
    field :scopes, {:array, :string}, default: []
    field :archive_emails, :boolean, default: true
    field :paused, :boolean, default: false
    field :last_synced_at, :utc_datetime

    belongs_to :user, Triage.Accounts.User
    has_many :emails, Triage.Emails.Email

    timestamps(type: :utc_datetime)
  end

  def changeset(email_account, attrs) do
    email_account
    |> cast(attrs, [
      :user_id,
      :provider,
      :email,
      :access_token,
      :refresh_token,
      :expires_at,
      :token_type,
      :scopes,
      :archive_emails,
      :paused,
      :last_synced_at
    ])
    |> validate_required([:user_id, :provider, :email, :access_token, :refresh_token])
    |> validate_inclusion(:provider, @providers)
    |> validate_email()
    |> unique_constraint([:user_id, :provider, :email])
    |> assoc_constraint(:user)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 255)
  end

  def update_token_changeset(email_account, attrs) do
    email_account
    |> cast(attrs, [
      :access_token,
      :refresh_token,
      :expires_at,
      :token_type,
      :scopes,
      :last_synced_at
    ])
  end

  def pause_changeset(email_account, attrs) do
    email_account
    |> cast(attrs, [:paused])
  end

  def archive_emails_changeset(email_account, attrs) do
    email_account
    |> cast(attrs, [:archive_emails])
  end

  def settings_changeset(email_account, attrs) do
    email_account
    |> cast(attrs, [:archive_emails, :paused])
  end
end
