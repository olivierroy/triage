defmodule TriageWeb.UserOAuthController do
  use TriageWeb, :controller

  alias Triage.Accounts
  alias Triage.Accounts.GoogleOAuth
  alias TriageWeb.UserAuth

  def request(conn, %{"provider" => "google"}) do
    client_id = Application.get_env(:triage, :google)[:client_id]
    client_secret = Application.get_env(:triage, :google)[:client_secret]
    redirect_uri = url(~p"/users/oauth/google/callback")

    config = [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri
    ]

    case GoogleOAuth.authorize_url(config) do
      {:ok, %{url: url}} ->
        redirect(conn, external: url)

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to authorize with Google")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(conn, %{"provider" => "google", "code" => code}) do
    client_id = Application.get_env(:triage, :google)[:client_id]
    client_secret = Application.get_env(:triage, :google)[:client_secret]
    redirect_uri = url(~p"/users/oauth/google/callback")

    config = [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri
    ]

    case Assent.Strategy.OIDC.callback(config, GoogleOAuth, %{"code" => code}) do
      {:ok, %{user: user, token: _token}} ->
        email = user["email"]
        name = user["name"]

        case Accounts.get_user_by_email(email) do
          nil ->
            case Accounts.register_user(%{
                   email: email,
                   password: random_password(),
                   full_name: name
                 }) do
              {:ok, user} ->
                Accounts.deliver_user_update_email_instructions(
                  user,
                  user.email,
                  &url(~p"/users/settings/confirm-email/#{&1}")
                )

                conn
                |> put_flash(:info, "Account created successfully.")
                |> UserAuth.log_in_user(user)

              {:error, _changeset} ->
                conn
                |> put_flash(:error, "Failed to create account with Google")
                |> redirect(to: ~p"/users/log-in")
            end

          user ->
            conn
            |> put_flash(:info, "Welcome back!")
            |> UserAuth.log_in_user(user)
        end

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to authenticate with Google")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(conn, %{"provider" => "google"}) do
    conn
    |> put_flash(:error, "Authentication with Google was cancelled")
    |> redirect(to: ~p"/users/log-in")
  end

  defp random_password do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
  end
end
