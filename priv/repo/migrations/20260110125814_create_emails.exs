defmodule Triage.Repo.Migrations.CreateEmails do
  use Ecto.Migration

  def change do
    create table(:emails) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :email_account_id, references(:email_accounts, on_delete: :delete_all), null: false
      add :gmail_message_id, :string, null: false
      add :thread_id, :string
      add :subject, :string
      add :from, :string
      add :to, {:array, :string}, default: []
      add :date, :utc_datetime
      add :body_html, :text
      add :body_text, :text
      add :labels, {:array, :string}, default: []
      add :snippet, :text
      add :internal_date, :utc_datetime
      add :summary, :text
      add :category_id, references(:categories, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:emails, [:user_id])
    create index(:emails, [:email_account_id])
    create unique_index(:emails, [:email_account_id, :gmail_message_id])
    create index(:emails, [:category_id])
    create index(:emails, [:date])
  end
end
