defmodule Triage.Encryption do
  @moduledoc """
  Wraps Cloak vault operations so we can optionally encrypt sensitive data
  whenever an encryption key is configured.
  """

  alias Triage.Vault

  @spec encrypt(binary()) :: binary()
  def encrypt(value) when is_binary(value) do
    if enabled?() do
      Vault.encrypt!(value)
    else
      value
    end
  end

  @spec decrypt(binary()) :: binary()
  def decrypt(value) when is_binary(value) do
    if enabled?() do
      Vault.decrypt!(value)
    else
      value
    end
  end

  defp enabled? do
    secret_key = Application.get_env(:triage, :encryption, [])[:secret_key]
    not is_nil(secret_key) and secret_key != ""
  end
end
