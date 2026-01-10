defmodule Triage.GmailFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Triage.Gmail` context.
  """

  alias Triage.Gmail
  alias Triage.Encryption

  alias Triage.Repo
  alias Triage.Accounts.Scope
  alias Triage.Emails.Email

  def unique_email, do: "email#{System.unique_integer([:positive])}@example.com"
  def unique_message_id, do: "msg_#{System.unique_integer([:positive])}"

  def email_account_fixture(scope_or_attrs \\ %{}, attrs \\ %{}) do
    {user_id, attrs} =
      case scope_or_attrs do
        %Scope{user: %{id: user_id}} -> {user_id, attrs}
        attrs when is_map(attrs) -> {attrs[:user_id], attrs}
      end

    if is_nil(user_id), do: raise("user_id is required")

    attrs =
      Enum.into(attrs, %{
        user_id: user_id,
        provider: "gmail",
        email: unique_email(),
        access_token: Encryption.encrypt("access_token"),
        refresh_token: Encryption.encrypt("refresh_token"),
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        token_type: "Bearer",
        scopes: ["https://www.googleapis.com/auth/gmail.modify"]
      })

    {:ok, email_account} = Gmail.create_email_account(attrs)

    # If keys are encrypted in create_email_account with manual encryption, the above might double encrypt if I am not careful.
    # checking Triage.Gmail.create_email_account:
    # It just passes attrs to changeset.
    # But wait, Triage.Gmail.callback encrypts BEFORE calling create_email_account.
    # So create_email_account expects ENCRYPTED tokens if I look at callback.
    # AND create_email_account stores them as is.
    # So providing encrypted tokens here is correct.

    email_account
  end

  def email_fixture(scope, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        user_id: scope.user.id,
        email_account_id: account.id,
        gmail_message_id: unique_message_id(),
        thread_id: "thread_#{System.unique_integer([:positive])}",
        subject: "Subject #{System.unique_integer([:positive])}",
        from: unique_email(),
        to: [unique_email()],
        date: DateTime.utc_now() |> DateTime.truncate(:second),
        snippet: "Snippet content...",
        internal_date: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, email} =
      %Email{}
      |> Email.changeset(attrs)
      |> Repo.insert()

    email
  end
end
