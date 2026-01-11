defmodule Triage.Encryption do
  @moduledoc """
  Wraps Cloak vault operations so we can optionally encrypt sensitive data
  whenever an encryption key is configured.
  """

  alias Triage.Vault

  @spec encrypt(binary() | nil) :: binary() | nil
  def encrypt(nil), do: nil

  def encrypt(value) when is_binary(value) do
    if enabled?() do
      value
      |> vault_module().encrypt!()
      |> Base.encode64()
    else
      value
    end
  end

  @spec decrypt(binary() | nil) :: binary() | nil
  def decrypt(nil), do: nil

  def decrypt(value) when is_binary(value) do
    if enabled?() do
      value
      |> decode_encrypted_value()
      |> vault_module().decrypt!()
    else
      value
    end
  rescue
    _ -> value
  end

  defp enabled? do
    secret_key = Application.get_env(:triage, :encryption, [])[:secret_key]
    not is_nil(secret_key) and secret_key != ""
  end

  defp vault_module do
    Application.get_env(:triage, :vault_module, Vault)
  end

  defp decode_encrypted_value(value) do
    case Base.decode64(value) do
      {:ok, decoded} -> decoded
      :error -> value
    end
  end
end
