defmodule Triage.GmailTest do
  use Triage.DataCase

  alias Triage.Accounts.Scope
  alias Triage.Gmail
  alias Triage.Unsubscribes

  import Triage.AccountsFixtures
  import Triage.GmailFixtures
  import Triage.CategoriesFixtures
  import Mox

  setup :verify_on_exit!

  describe "email accounts" do
    test "list_email_accounts/1 returns all email accounts for a user" do
      user = user_fixture()
      scope = %Scope{user: user}
      email_account = email_account_fixture(scope)

      assert Gmail.list_email_accounts(scope) == [email_account]
    end

    test "get_email_account!/2 returns the email account with given id" do
      user = user_fixture()
      scope = %Scope{user: user}
      email_account = email_account_fixture(scope)

      assert Gmail.get_email_account!(scope, email_account.id) == email_account
    end
  end

  describe "emails" do
    setup do
      user = user_fixture()
      scope = %Scope{user: user}
      account = email_account_fixture(scope)
      {:ok, scope: scope, account: account}
    end

    test "list_emails/2 returns emails with limits and offsets", %{scope: scope, account: account} do
      _email1 = email_fixture(scope, account)
      _email2 = email_fixture(scope, account)

      assert length(Gmail.list_emails(scope, limit: 1)) == 1
    end

    test "list_emails/2 filters by category", %{scope: scope, account: account} do
      category = category_fixture(scope)
      email_in_cat = email_fixture(scope, account, %{category_id: category.id})
      _email_out_cat = email_fixture(scope, account)

      emails = Gmail.list_emails(scope, category_id: category.id)
      assert length(emails) == 1
      assert hd(emails).id == email_in_cat.id
    end

    test "list_emails/2 filters by 'none' category", %{scope: scope, account: account} do
      category = category_fixture(scope)
      _email_in_cat = email_fixture(scope, account, %{category_id: category.id})
      email_out_cat = email_fixture(scope, account)

      emails = Gmail.list_emails(scope, category_id: nil)
      assert length(emails) == 1
      assert hd(emails).id == email_out_cat.id
    end

    test "list_emails/2 sorts inbox emails by newest date first", %{
      scope: scope,
      account: account
    } do
      now = DateTime.utc_now()

      newest = email_fixture(scope, account, %{date: DateTime.add(now, 3600, :second)})

      mid =
        email_fixture(scope, account, %{
          date: nil,
          internal_date: DateTime.add(now, 1800, :second)
        })

      oldest = email_fixture(scope, account, %{date: DateTime.add(now, -7200, :second)})

      assert Enum.map(Gmail.list_emails(scope), & &1.id) == [newest.id, mid.id, oldest.id]
    end

    test "count_emails/2 returns the total count of emails", %{scope: scope, account: account} do
      email_fixture(scope, account)
      email_fixture(scope, account)

      assert Gmail.count_emails(scope) == 2
    end

    test "count_emails/2 with filters", %{scope: scope, account: account} do
      category = category_fixture(scope)
      email_fixture(scope, account, %{category_id: category.id})
      email_fixture(scope, account, %{category_id: nil})

      assert Gmail.count_emails(scope, category_id: category.id) == 1
      assert Gmail.count_emails(scope, category_id: nil) == 1
    end

    test "import_emails/2 imports and categorizes emails", %{scope: scope, account: account} do
      # 1. Mock list_messages
      expect(Triage.Gmail.ClientMock, :list_messages, fn _token, _opts ->
        {:ok, [%{"id" => "msg123"}], nil}
      end)

      # 2. Mock get_message
      expect(Triage.Gmail.ClientMock, :get_message, fn _token, "msg123", _opts ->
        {:ok,
         %{
           "id" => "msg123",
           "threadId" => "t123",
           "internalDate" => "#{System.system_time(:millisecond)}",
           "labelIds" => ["INBOX"],
           "payload" => %{
             "headers" => [
               %{"name" => "Subject", "value" => "Test AI"},
               %{"name" => "From", "value" => "sender@test.com"},
               %{"name" => "Date", "value" => DateTime.to_iso8601(DateTime.utc_now())}
             ]
           },
           "snippet" => "This is a test snippet"
         }}
      end)

      # 3. Mock AI service
      expect(Triage.Gmail.AIMock, :categorize_and_summarize, fn _attrs, _categories ->
        {:ok, %{category_id: nil, summary: "Mocked summary"}}
      end)

      # 4. Mock modify_message (for archiving)
      stub(Triage.Gmail.ClientMock, :modify_message, fn _token, _id, _payload, _opts ->
        {:ok, %{}}
      end)

      assert {:ok, 1} = Gmail.import_emails(account)

      imported = Gmail.list_emails(scope)
      assert length(imported) == 1
      assert hd(imported).summary == "Mocked summary"
    end

    test "import_emails/2 skips already imported messages without using AI", %{
      scope: scope,
      account: account
    } do
      existing = email_fixture(scope, account, %{gmail_message_id: "msg-existing"})

      expect(Triage.Gmail.ClientMock, :list_messages, fn _token, _opts ->
        {:ok, [%{"id" => existing.gmail_message_id}], nil}
      end)

      expect(Triage.Gmail.ClientMock, :get_message, 0, fn _token, _message_id, _opts ->
        flunk("get_message should not be called for already imported emails")
      end)

      expect(Triage.Gmail.AIMock, :categorize_and_summarize, 0, fn _attrs, _categories ->
        flunk("AI should not categorize already imported emails")
      end)

      assert {:ok, 0} = Gmail.import_emails(account)

      # Ensure the existing email is still present and unchanged
      assert [fetched] = Gmail.list_emails(scope)
      assert fetched.id == existing.id
    end

    test "import_emails/2 processes only unseen messages when mix contains duplicates", %{
      scope: scope,
      account: account
    } do
      existing = email_fixture(scope, account, %{gmail_message_id: "msg-existing"})

      expect(Triage.Gmail.ClientMock, :list_messages, fn _token, _opts ->
        {:ok, [%{"id" => existing.gmail_message_id}, %{"id" => "msg-new"}], nil}
      end)

      expect(Triage.Gmail.ClientMock, :get_message, fn _token, "msg-new", _opts ->
        {:ok,
         %{
           "id" => "msg-new",
           "threadId" => "t456",
           "internalDate" => "#{System.system_time(:millisecond)}",
           "labelIds" => ["INBOX"],
           "payload" => %{
             "headers" => [
               %{"name" => "Subject", "value" => "Fresh"},
               %{"name" => "From", "value" => "sender@test.com"},
               %{"name" => "Date", "value" => DateTime.to_iso8601(DateTime.utc_now())}
             ]
           },
           "snippet" => "Brand new"
         }}
      end)

      expect(Triage.Gmail.AIMock, :categorize_and_summarize, fn attrs, _categories ->
        assert attrs.subject == "Fresh"
        {:ok, %{category_id: nil, summary: "Fresh summary"}}
      end)

      stub(Triage.Gmail.ClientMock, :modify_message, fn _token, _id, _payload, _opts ->
        {:ok, %{}}
      end)

      assert {:ok, 1} = Gmail.import_emails(account)

      summaries = Gmail.list_emails(scope) |> Enum.map(& &1.summary)
      assert "Fresh summary" in summaries
      assert Enum.count(summaries) == 2
    end

    test "import_emails/2 skips messages not in INBOX", %{scope: scope, account: account} do
      expect(Triage.Gmail.ClientMock, :list_messages, fn _token, _opts ->
        {:ok, [%{"id" => "sent-msg"}], nil}
      end)

      expect(Triage.Gmail.ClientMock, :get_message, fn _token, "sent-msg", _opts ->
        {:ok,
         %{
           "id" => "sent-msg",
           "threadId" => "thread-1",
           "internalDate" => "#{System.system_time(:millisecond)}",
           "labelIds" => ["CATEGORY_PERSONAL"],
           "payload" => %{
             "headers" => [
               %{"name" => "Subject", "value" => "Sent mail"},
               %{"name" => "From", "value" => "user@example.com"},
               %{"name" => "Date", "value" => DateTime.to_iso8601(DateTime.utc_now())}
             ]
           },
           "snippet" => "Sent snippet"
         }}
      end)

      expect(Triage.Gmail.AIMock, :categorize_and_summarize, 0, fn _attrs, _categories ->
        flunk("AI service should not be invoked for non-INBOX messages")
      end)

      assert {:ok, 0} = Gmail.import_emails(account)
      assert [] == Gmail.list_emails(scope)
    end

    test "unsubscribe_email/2 persists unsubscribe attempts", %{scope: scope, account: account} do
      email = email_fixture(scope, account)

      expect(Triage.Gmail.AIMock, :unsubscribe_from_email, fn attrs ->
        assert attrs.subject == email.subject

        {:ok,
         %{
           unsubscribe_url: "https://example.com/unsubscribe",
           status: :failed,
           message: "manual"
         }}
      end)

      assert {:error, "manual"} = Gmail.unsubscribe_email(scope, email.id)

      [attempt] = Unsubscribes.list_unsubscribes(scope)
      assert attempt.status == :failed
      assert attempt.unsubscribe_url == "https://example.com/unsubscribe"
      assert attempt.from_email == email.from
    end

    test "unsubscribe_email/2 returns error when no link is found", %{
      scope: scope,
      account: account
    } do
      email = email_fixture(scope, account)

      expect(Triage.Gmail.AIMock, :unsubscribe_from_email, fn _attrs ->
        {:ok, %{status: :not_found, message: "No link"}}
      end)

      assert {:error, "No link"} = Gmail.unsubscribe_email(scope, email.id)
      assert [] == Unsubscribes.list_unsubscribes(scope)
    end

    test "unsubscribe_emails/2 returns aggregated results", %{scope: scope, account: account} do
      email_one = email_fixture(scope, account)
      email_two = email_fixture(scope, account)

      expect(Triage.Gmail.AIMock, :unsubscribe_from_email, fn _attrs ->
        {:ok,
         %{
           unsubscribe_url: "https://example.com/success",
           status: :success,
           message: "done"
         }}
      end)

      expect(Triage.Gmail.AIMock, :unsubscribe_from_email, fn _attrs ->
        {:error, "not found"}
      end)

      assert {:ok, %{successes: 1, failures: 1}} =
               Gmail.unsubscribe_emails(scope, [email_one.id, email_two.id])

      [attempt] = Unsubscribes.list_unsubscribes(scope)
      assert attempt.status == :success
    end
  end
end
