defmodule Triage.Repo.Migrations.CreateEmailAccounts do
  use Ecto.Migration

  def change do
    create table(:email_accounts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :email, :string, null: false
      add :access_token, :text, null: false
      add :refresh_token, :text, null: false
      add :expires_at, :utc_datetime
      add :token_type, :string
      add :scopes, {:array, :string}, default: []
      add :archive_emails, :boolean, default: true, null: false
      add :paused, :boolean, default: false, null: false
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:email_accounts, [:user_id])
    create unique_index(:email_accounts, [:user_id, :provider, :email])
  end
end
