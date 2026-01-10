defmodule Triage.Vault do
  use Cloak.Vault, otp_app: :triage

  @impl true
  def init(config) do
    secret_key = Application.get_env(:triage, :encryption)[:secret_key]

    if secret_key do
      key = Base.decode64!(secret_key)

      {:ok,
       Keyword.put(config, :ciphers,
         default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key, iv_length: 12}
       )}
    else
      {:ok, config}
    end
  end
end
