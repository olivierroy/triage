defmodule Triage.Encryption.TestVault do
  @moduledoc false

  @prefix <<0, 173, 255>>

  def encrypt!(value) do
    @prefix <> value
  end

  def decrypt!(@prefix <> value), do: value
  def decrypt!(_value), do: raise(ArgumentError, "not an encrypted value")
end

defmodule Triage.EncryptionDisabledTest do
  use ExUnit.Case, async: true

  alias Triage.Encryption

  setup do
    Application.delete_env(:triage, :encryption)
    Application.delete_env(:triage, :vault_module)
    :ok
  end

  test "encrypt/1 and decrypt/1 are no-ops without configuration" do
    value = "plain-text"

    assert Encryption.encrypt(value) == value
    assert Encryption.decrypt(value) == value
  end
end

defmodule Triage.EncryptionEnabledTest do
  use ExUnit.Case, async: true

  alias Triage.Encryption
  alias Triage.Encryption.TestVault

  setup_all do
    key = Base.encode64(:crypto.strong_rand_bytes(32))
    Application.put_env(:triage, :encryption, secret_key: key)
    Application.put_env(:triage, :vault_module, TestVault)

    on_exit(fn ->
      Application.delete_env(:triage, :encryption)
      Application.delete_env(:triage, :vault_module)
    end)

    :ok
  end

  test "encrypt/1 returns base64 encoded ciphertext" do
    value = "super-secret"

    encrypted = Encryption.encrypt(value)

    refute encrypted == value
    assert {:ok, decoded} = Base.decode64(encrypted)
    assert decoded == TestVault.encrypt!(value)
    assert Encryption.decrypt(encrypted) == value
  end

  test "decrypt/1 handles plaintext values for backwards compatibility" do
    value = "plaintext-token"
    assert Encryption.decrypt(value) == value
  end

  test "decrypt/1 handles ciphertext stored before base64 encoding" do
    value = "another-secret"
    ciphertext = TestVault.encrypt!(value)

    assert Encryption.decrypt(ciphertext) == value
  end
end
