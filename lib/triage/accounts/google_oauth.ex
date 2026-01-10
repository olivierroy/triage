defmodule Triage.Accounts.GoogleOAuth do
  @moduledoc """
  Google OAuth strategy using Assent.
  """

  @doc """
  Builds a configuration keyword list for Google OAuth using the app env defaults.
  """
  def config(overrides \\ []) do
    base_config =
      Application.get_env(:triage, :google, [])
      |> Keyword.take([:client_id, :client_secret, :redirect_uri])

    Keyword.merge(base_config, overrides, fn
      :authorization_params, _base, custom -> custom
      _key, _base, custom -> custom
    end)
  end

  @doc """
  Generates a list of authorization params with the desired scope.
  """
  def authorization_params(scope, extra \\ []) do
    Keyword.merge([scope: scope], extra)
  end

  def authorize_url(config) do
    Assent.Strategy.Google.authorize_url(config)
  end

  def callback(config, params) do
    Assent.Strategy.Google.callback(config, params)
  end
end
