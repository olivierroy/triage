defmodule Triage.GmailFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Triage.Gmail` context.
  """

  alias Triage.Gmail
  alias Triage.Encryption

  def unique_email, do: "email#{System.unique_integer()}@example.com"

  def email_account_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || raise "user_id is required"

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
end
