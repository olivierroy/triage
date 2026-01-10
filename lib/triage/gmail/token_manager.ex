defmodule Triage.Gmail.TokenManager do
  @moduledoc """
  GenServer for managing Gmail token lifecycle.
  Caches tokens and handles auto-refresh for expired tokens.
  """

  use GenServer
  require Logger

  alias Triage.Gmail
  alias Triage.EmailAccounts.EmailAccount

  @refresh_threshold_seconds 300

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_valid_token(%EmailAccount{} = email_account) do
    GenServer.call(__MODULE__, {:get_valid_token, email_account})
  end

  def refresh_token(%EmailAccount{} = email_account) do
    GenServer.cast(__MODULE__, {:refresh_token, email_account})
  end

  def cache_token(%EmailAccount{} = email_account, access_token) do
    GenServer.cast(__MODULE__, {:cache_token, email_account.id, access_token})
  end

  def clear_cache(%EmailAccount{} = email_account) do
    GenServer.cast(__MODULE__, {:clear_cache, email_account.id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_valid_token, email_account}, _from, state) do
    result =
      case get_cached_token(state, email_account.id) do
        {:ok, token} ->
          {:ok, token}

        {:error, :not_cached} ->
          case Gmail.get_valid_token(email_account) do
            {:ok, token} ->
              {:ok, token}

            error ->
              error
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:refresh_token, email_account}, state) do
    Task.start(fn ->
      case Gmail.refresh_token(email_account) do
        {:ok, _updated_account} ->
          Logger.info("Refreshed token for email account #{email_account.id}")

        {:error, error} ->
          Logger.error(
            "Failed to refresh token for email account #{email_account.id}: #{inspect(error)}"
          )
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:cache_token, email_account_id, access_token}, state) do
    {:noreply,
     Map.put(state, email_account_id, %{token: access_token, cached_at: DateTime.utc_now()})}
  end

  @impl true
  def handle_cast({:clear_cache, email_account_id}, state) do
    {:noreply, Map.delete(state, email_account_id)}
  end

  defp get_cached_token(state, email_account_id) do
    case Map.get(state, email_account_id) do
      nil ->
        {:error, :not_cached}

      %{token: token, cached_at: cached_at} ->
        if DateTime.diff(DateTime.utc_now(), cached_at) > @refresh_threshold_seconds do
          {:error, :expired}
        else
          {:ok, token}
        end
    end
  end
end
