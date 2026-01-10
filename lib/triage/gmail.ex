defmodule Triage.Gmail do
  @moduledoc """
  Main context module for Gmail integration.
  """

  import Ecto.Query, warn: false

  alias Triage.Accounts.{GoogleOAuth, Scope}
  alias Triage.Encryption
  alias Triage.EmailAccounts.EmailAccount
  alias Triage.Emails.Email
  alias Triage.Gmail.Client
  alias Triage.Repo

  @gmail_scope "https://www.googleapis.com/auth/gmail.modify"

  def authorize_url(_scope) do
    config =
      GoogleOAuth.config(
        client_secret: "",
        authorization_params:
          GoogleOAuth.authorization_params(@gmail_scope,
            access_type: "offline",
            prompt: "consent select_account"
          )
      )

    case GoogleOAuth.authorize_url(config) do
      {:ok, %{url: url, session_params: session_params}} ->
        {:ok, %{url: url, session_params: session_params}}

      {:error, error} ->
        {:error, error}
    end
  end

  def callback(%Scope{user: user}, params, session_params) do
    config =
      GoogleOAuth.config(
        authorization_params: GoogleOAuth.authorization_params(@gmail_scope),
        session_params: session_params
      )

    case GoogleOAuth.callback(config, params) do
      {:ok, %{token: token, user: google_user}} ->
        access_token = token["access_token"]
        refresh_token = token["refresh_token"]
        expires_in = token["expires_in"]
        token_type = token["token_type"]
        scopes = token["scope"] |> String.split(" ")
        email = google_user["email"]

        expires_at =
          DateTime.add(DateTime.utc_now(), expires_in, :second)

        email_account_attrs = %{
          user_id: user.id,
          provider: "gmail",
          email: email,
          access_token: Encryption.encrypt(access_token),
          refresh_token: Encryption.encrypt(refresh_token),
          expires_at: expires_at,
          token_type: token_type,
          scopes: scopes
        }

        create_email_account(email_account_attrs)

      {:error, error} ->
        {:error, error}
    end
  end

  def callback(_, _, _) do
    {:error, "Invalid OAuth callback"}
  end

  def list_email_accounts(%Scope{user: %{id: user_id}}) do
    EmailAccount
    |> where([ea], ea.user_id == ^user_id)
    |> order_by([ea], desc: ea.inserted_at)
    |> Repo.all()
  end

  def list_email_accounts(_), do: []

  def get_email_account!(%Scope{user: %{id: user_id}}, id) do
    Repo.get_by!(EmailAccount, id: id, user_id: user_id)
  end

  def create_email_account(attrs) do
    %EmailAccount{}
    |> EmailAccount.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          access_token: attrs.access_token,
          refresh_token: attrs.refresh_token,
          expires_at: attrs.expires_at,
          token_type: attrs.token_type,
          scopes: attrs.scopes
        ]
      ],
      conflict_target: [:user_id, :provider, :email]
    )
  end

  def update_email_account(email_account, attrs) do
    email_account
    |> EmailAccount.update_token_changeset(attrs)
    |> Repo.update()
  end

  def pause_email_account(email_account, paused? \\ true) do
    email_account
    |> EmailAccount.pause_changeset(%{paused: paused?})
    |> Repo.update()
  end

  def archive_emails_setting(email_account, archive? \\ true) do
    email_account
    |> EmailAccount.archive_emails_changeset(%{archive_emails: archive?})
    |> Repo.update()
  end

  def update_email_account_settings(email_account, attrs) do
    email_account
    |> EmailAccount.settings_changeset(attrs)
    |> Repo.update()
  end

  def delete_email_account(%EmailAccount{} = email_account) do
    Repo.delete(email_account)
  end

  def refresh_token(%EmailAccount{} = email_account) do
    refresh_token = Encryption.decrypt(email_account.refresh_token)
    client_id = Application.get_env(:triage, :google)[:client_id]
    client_secret = Application.get_env(:triage, :google)[:client_secret]

    url = "https://oauth2.googleapis.com/token"

    case Req.post(url,
           form: [
             client_id: client_id,
             client_secret: client_secret,
             refresh_token: refresh_token,
             grant_type: "refresh_token"
           ]
         ) do
      {:ok, %{body: body}} when is_map(body) ->
        access_token = Map.get(body, "access_token")
        expires_in = Map.get(body, "expires_in", 3600)
        token_type = Map.get(body, "token_type", "Bearer")

        expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)

        update_attrs = %{
          access_token: Encryption.encrypt(access_token),
          expires_at: expires_at,
          token_type: token_type
        }

        update_email_account(email_account, update_attrs)

      {:error, error} ->
        {:error, error}
    end
  end

  def get_valid_token(%EmailAccount{} = email_account) do
    if DateTime.compare(DateTime.utc_now(), email_account.expires_at) == :lt do
      {:ok, Encryption.decrypt(email_account.access_token)}
    else
      case refresh_token(email_account) do
        {:ok, updated_account} ->
          {:ok, Encryption.decrypt(updated_account.access_token)}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  def fetch_emails(%EmailAccount{} = email_account, opts \\ []) do
    case get_valid_token(email_account) do
      {:ok, access_token} ->
        fetch_opts = add_date_filter(opts, email_account.inserted_at)
        fetch_all_emails(access_token, fetch_opts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp add_date_filter(opts, nil), do: opts

  defp add_date_filter(opts, %DateTime{} = account_created_at) do
    existing_query = Keyword.get(opts, :query, "")
    date_filter = "after:#{format_date_for_gmail(account_created_at)}"

    updated_query =
      if existing_query == "" do
        date_filter
      else
        "#{existing_query} #{date_filter}"
      end

    Keyword.put(opts, :query, updated_query)
  end

  defp format_date_for_gmail(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp fetch_all_emails(access_token, opts, acc \\ [], page_token \\ nil) do
    fetch_opts = Keyword.put(opts, :page_token, page_token)

    case Client.list_messages(access_token, fetch_opts) do
      {:ok, messages, nil} when messages == [] ->
        {:ok, Enum.reverse(acc)}

      {:ok, messages, nil} ->
        {:ok, Enum.reverse(messages ++ acc)}

      {:ok, messages, next_page_token} ->
        fetch_all_emails(access_token, opts, messages ++ acc, next_page_token)

      {:error, error} ->
        {:error, error}
    end
  end

  def import_emails(%EmailAccount{} = email_account, opts \\ []) do
    case fetch_emails(email_account, opts) do
      {:ok, messages} ->
        imported = import_messages(email_account, messages)
        {:ok, length(imported)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp import_messages(email_account, messages) do
    scope = Triage.Accounts.Scope.for_user(email_account.user_id)
    categories = Triage.Categories.list_categories(scope)

    case get_valid_token(email_account) do
      {:ok, access_token} ->
        messages
        |> Task.async_stream(
          &import_single_message(access_token, email_account, &1, categories),
          max_concurrency: 5,
          timeout: :infinity
        )
        |> Enum.filter(fn
          {:ok, {:ok, _}} -> true
          _ -> false
        end)
        |> Enum.map(fn {:ok, result} -> result end)

      {:error, _} ->
        []
    end
  end

  defp import_single_message(access_token, email_account, %{"id" => message_id}, categories) do
    with {:ok, gmail_message} <- Client.get_message(access_token, message_id),
         {:ok, email_attrs} <- parse_gmail_message(gmail_message, email_account) do
      # Categorize and summarize using AI
      email_attrs =
        case Triage.Gmail.AI.categorize_and_summarize(email_attrs, categories) do
          {:ok, ai_result} ->
            Map.merge(email_attrs, ai_result)

          {:error, _error} ->
            email_attrs
        end

      case upsert_email(email_attrs) do
        {:ok, email} -> {:ok, email}
        error -> error
      end
    else
      error -> error
    end
  end

  defp parse_gmail_message(
         %{
           "id" => message_id,
           "threadId" => thread_id,
           "payload" => payload,
           "internalDate" => internal_date
         },
         email_account
       ) do
    headers = extract_headers(payload)
    subject = get_header(headers, "Subject")
    from = get_header(headers, "From")
    to = get_header(headers, "To")
    date = parse_date(get_header(headers, "Date"))

    body = extract_body(payload)

    internal_date_ts = String.to_integer(internal_date)
    internal_datetime = DateTime.from_unix!(internal_date_ts, :millisecond)

    labels = get_in(payload, ["labelIds"]) || []

    email_attrs = %{
      user_id: email_account.user_id,
      email_account_id: email_account.id,
      gmail_message_id: message_id,
      thread_id: thread_id,
      subject: subject,
      from: from,
      to: parse_recipients(to),
      date: date,
      body_html: body[:html],
      body_text: body[:text],
      labels: labels,
      snippet: get_in(payload, ["snippet"]),
      internal_date: internal_datetime
    }

    {:ok, email_attrs}
  end

  defp parse_gmail_message(_, _), do: {:error, "Invalid Gmail message format"}

  defp extract_headers(payload) do
    payload
    |> get_in(["headers"])
    |> case do
      nil -> []
      headers -> headers
    end
    |> Enum.reduce(%{}, fn %{"name" => name, "value" => value}, acc ->
      Map.put(acc, name, value)
    end)
  end

  defp get_header(headers, key) do
    Map.get(headers, key) || Map.get(headers, String.downcase(key))
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) do
    try do
      case DateTime.from_iso8601(date_str) do
        {:ok, datetime} -> datetime
        {:error, _} -> parse_rfc1123(date_str)
      end
    rescue
      _ -> nil
    end
  end

  defp parse_rfc1123(date_str) do
    case NaiveDateTime.from_iso8601(date_str) do
      {:ok, naive_datetime} ->
        DateTime.from_naive!(naive_datetime, "Etc/UTC")

      _ ->
        parse_httpd_date(date_str)
    end
  rescue
    _ -> nil
  end

  defp parse_httpd_date(date_str) do
    date_str
    |> String.to_charlist()
    |> :httpd_util.convert_request_date()
    |> case do
      {{_, _, _}, {_, _, _}} = erl_datetime ->
        erl_datetime
        |> NaiveDateTime.from_erl!()
        |> DateTime.from_naive!("Etc/UTC")

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp extract_body(payload) do
    case extract_body_part(payload) do
      {:ok, html, text} -> %{html: html, text: text}
      _ -> %{html: nil, text: nil}
    end
  end

  defp extract_body_part(%{"body" => %{"data" => data}} = payload) do
    decoded = Base.url_decode64!(data, ignore: :whitespace)
    content_type = get_header(extract_headers(payload), "Content-Type")

    if String.contains?(content_type || "", "text/html") do
      {:ok, decoded, nil}
    else
      {:ok, nil, decoded}
    end
  end

  defp extract_body_part(%{"parts" => parts}) do
    parts
    |> Enum.reduce({nil, nil}, fn part, {html_acc, text_acc} ->
      case extract_body_part(part) do
        {:ok, html, text} ->
          {html || html_acc, text || text_acc}

        _ ->
          {html_acc, text_acc}
      end
    end)
    |> case do
      {nil, nil} -> {:error, "No body found"}
      {html, text} -> {:ok, html, text}
    end
  end

  defp extract_body_part(_), do: {:error, "No body found"}

  defp parse_recipients(nil), do: []

  defp parse_recipients(recipients_str) do
    recipients_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp upsert_email(attrs) do
    changeset = Email.changeset(%Email{}, attrs)

    Repo.insert(
      changeset,
      on_conflict: [
        set: [
          subject: attrs.subject,
          from: attrs.from,
          to: attrs.to,
          date: attrs.date,
          body_html: attrs.body_html,
          body_text: attrs.body_text,
          labels: attrs.labels,
          snippet: attrs.snippet,
          internal_date: attrs.internal_date,
          updated_at: DateTime.utc_now()
        ]
      ],
      conflict_target: [:email_account_id, :gmail_message_id]
    )
  end

  def count_emails_by_category(%Scope{user: %{id: user_id}}) do
    Email
    |> where([e], e.user_id == ^user_id)
    |> group_by([e], e.category_id)
    |> select([e], {e.category_id, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  def list_emails(%Scope{user: %{id: user_id}}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    category_id = Keyword.get(opts, :category_id)
    has_category = Keyword.has_key?(opts, :category_id)
    email_account_id = Keyword.get(opts, :email_account_id)

    query =
      Email
      |> where([e], e.user_id == ^user_id)
      |> order_by([e], desc: e.date)
      |> limit(^limit)
      |> offset(^offset)

    query =
      cond do
        category_id ->
          where(query, [e], e.category_id == ^category_id)

        has_category and is_nil(category_id) ->
          where(query, [e], is_nil(e.category_id))

        true ->
          query
      end

    query =
      if email_account_id do
        where(query, [e], e.email_account_id == ^email_account_id)
      else
        query
      end

    query
    |> Repo.all()
    |> Repo.preload(:email_account)
  end

  def count_emails(%Scope{user: %{id: user_id}}, opts \\ []) do
    category_id = Keyword.get(opts, :category_id)
    has_category = Keyword.has_key?(opts, :category_id)
    email_account_id = Keyword.get(opts, :email_account_id)

    query =
      Email
      |> where([e], e.user_id == ^user_id)

    query =
      cond do
        category_id ->
          where(query, [e], e.category_id == ^category_id)

        has_category and is_nil(category_id) ->
          where(query, [e], is_nil(e.category_id))

        true ->
          query
      end

    query =
      if email_account_id do
        where(query, [e], e.email_account_id == ^email_account_id)
      else
        query
      end

    Repo.aggregate(query, :count, :id)
  end

  def get_email!(%Scope{user: %{id: user_id}}, id) do
    Repo.get_by!(Email, id: id, user_id: user_id)
  end

  def delete_email(%Scope{} = scope, id, opts \\ []) do
    email = get_email!(scope, id) |> Repo.preload(:email_account)

    with {:ok, access_token} <- get_valid_token(email.email_account),
         :ok <- Client.trash_message(access_token, email.gmail_message_id, opts) do
      Repo.delete(email)
    end
  end

  def update_email_category(%Email{} = email, category_id) do
    email
    |> Email.update_category_changeset(%{category_id: category_id})
    |> Repo.update()
  end

  def reprocess_email(%Scope{} = scope, id) do
    email = get_email!(scope, id)
    categories = Triage.Categories.list_categories(scope)

    # Convert email to attrs for AI service
    email_attrs = %{
      subject: email.subject,
      from: email.from,
      snippet: email.snippet
    }

    case Triage.Gmail.AI.categorize_and_summarize(email_attrs, categories) do
      {:ok, ai_result} ->
        email
        |> Email.changeset(ai_result)
        |> Repo.update()

      {:error, error} ->
        {:error, error}
    end
  end
end
