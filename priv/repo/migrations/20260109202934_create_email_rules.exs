defmodule Triage.Repo.Migrations.CreateEmailRules do
  use Ecto.Migration

  def change do
    create table(:email_rules) do
      add :name, :string, null: false
      add :action, :string, null: false, default: "process"
      add :archive, :boolean, null: false, default: true
      add :match_senders, {:array, :string}, null: false, default: []
      add :match_subject_keywords, {:array, :string}, null: false, default: []
      add :match_body_keywords, {:array, :string}, null: false, default: []
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:email_rules, [:user_id])
    create unique_index(:email_rules, [:user_id, :name])
  end
end
