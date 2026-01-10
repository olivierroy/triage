defmodule Triage.Emails.Email do
  use Ecto.Schema
  import Ecto.Changeset

  schema "emails" do
    field :gmail_message_id, :string
    field :thread_id, :string
    field :subject, :string
    field :from, :string
    field :to, {:array, :string}, default: []
    field :date, :utc_datetime
    field :body_html, :string
    field :body_text, :string
    field :labels, {:array, :string}, default: []
    field :snippet, :string
    field :internal_date, :utc_datetime
    field :summary, :string

    belongs_to :user, Triage.Accounts.User
    belongs_to :email_account, Triage.EmailAccounts.EmailAccount
    belongs_to :category, Triage.Categories.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [
      :user_id,
      :email_account_id,
      :gmail_message_id,
      :thread_id,
      :subject,
      :from,
      :to,
      :date,
      :body_html,
      :body_text,
      :labels,
      :snippet,
      :internal_date,
      :summary,
      :category_id
    ])
    |> validate_required([:user_id, :email_account_id, :gmail_message_id])
    |> unique_constraint([:email_account_id, :gmail_message_id])
    |> assoc_constraint(:user)
    |> assoc_constraint(:email_account)
    |> assoc_constraint(:category)
  end

  def update_category_changeset(email, attrs) do
    email
    |> cast(attrs, [:category_id])
    |> validate_required([:category_id])
  end
end
