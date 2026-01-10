defmodule Triage.GmailTest do
  use Triage.DataCase

  alias Triage.Gmail
  alias Triage.Accounts.Scope

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
  end
end
