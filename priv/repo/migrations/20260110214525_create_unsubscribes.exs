defmodule Triage.Repo.Migrations.CreateUnsubscribes do
  use Ecto.Migration

  def up do
    create table(:unsubscribes) do
      add :status, :string, default: "success", null: false
      add :unsubscribe_url, :text, null: false
      add :error_message, :text
      add :confirmed_message, :text
      add :page_content, :text
      add :flow_type, :string
      add :attempted_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :from_email, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:unsubscribes, [:user_id])
    create index(:unsubscribes, [:status])
  end

  def down do
    drop table(:unsubscribes)
  end
end
