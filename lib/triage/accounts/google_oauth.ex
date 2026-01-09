defmodule Triage.Accounts.GoogleOAuth do
  @moduledoc """
  Google OAuth strategy using Assent.
  """
  use Assent.Strategy.OIDC.Base

  def default_config(config) do
    [
      site: "https://accounts.google.com",
      authorization_params: [
        scope: "email profile"
      ]
    ] ++ config
  end
end
