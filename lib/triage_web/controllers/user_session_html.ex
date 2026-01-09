defmodule TriageWeb.UserSessionHTML do
  use TriageWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:triage, Triage.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
