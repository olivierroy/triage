defmodule Triage.Gmail.Client do
  @moduledoc """
  Low-level Gmail API client using Req.
  """

  require Logger

  @base_url "https://www.googleapis.com/gmail/v1/users"

  def list_messages(access_token, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "me")
    max_results = Keyword.get(opts, :max_results, 100)
    page_token = Keyword.get(opts, :page_token)
    query = Keyword.get(opts, :query)
    include_spam_trash = Keyword.get(opts, :include_spam_trash, false)

    params = [
      maxResults: max_results,
      includeSpamTrash: include_spam_trash
    ]

    params = if page_token, do: [{:pageToken, page_token} | params], else: params
    params = if query, do: [{:q, query} | params], else: params

    url = "#{@base_url}/#{user_id}/messages"

    case req_get(url, access_token, params: params) do
      {:ok, %{body: body}} ->
        messages = Map.get(body, "messages", [])
        next_page_token = Map.get(body, "nextPageToken")
        {:ok, messages, next_page_token}

      {:error, reason} ->
        Logger.error("Failed to list Gmail messages: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_message(access_token, message_id, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "me")
    format = Keyword.get(opts, :format, "full")
    metadata_headers = Keyword.get(opts, :metadata_headers, [])

    params = [format: format]

    params =
      if metadata_headers == [] do
        params
      else
        [{:metadataHeaders, metadata_headers} | params]
      end

    url = "#{@base_url}/#{user_id}/messages/#{message_id}"

    case req_get(url, access_token, params: params) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, reason} ->
        Logger.error("Failed to get Gmail message #{message_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_thread(access_token, thread_id, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "me")
    format = Keyword.get(opts, :format, "full")
    metadata_headers = Keyword.get(opts, :metadata_headers, [])

    params = [format: format]

    params =
      if metadata_headers == [] do
        params
      else
        [{:metadataHeaders, metadata_headers} | params]
      end

    url = "#{@base_url}/#{user_id}/threads/#{thread_id}"

    case req_get(url, access_token, params: params) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, reason} ->
        Logger.error("Failed to get Gmail thread #{thread_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_labels(access_token, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "me")

    url = "#{@base_url}/#{user_id}/labels"

    case req_get(url, access_token) do
      {:ok, %{body: body}} ->
        labels = Map.get(body, "labels", [])
        {:ok, labels}

      {:error, reason} ->
        Logger.error("Failed to get Gmail labels: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def modify_message(access_token, message_id, payload, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "me")

    url = "#{@base_url}/#{user_id}/messages/#{message_id}/modify"

    case req_post(url, access_token, payload) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, reason} ->
        Logger.error("Failed to modify Gmail message #{message_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp req_get(url, access_token, opts \\ []) do
    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    Req.get(url, Keyword.merge(opts, headers: headers))
  end

  defp req_post(url, access_token, body, opts \\ []) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    Req.post(url, Keyword.merge(opts, headers: headers, json: body))
  end
end
