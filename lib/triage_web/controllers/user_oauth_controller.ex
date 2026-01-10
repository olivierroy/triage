defmodule TriageWeb.UserOAuthController do
  use TriageWeb, :controller
  require Logger

  alias Triage.Accounts
  alias Triage.Accounts.GoogleOAuth
  alias Triage.Encryption
  alias Triage.Gmail
  alias TriageWeb.UserAuth

  @gmail_scope "https://www.googleapis.com/auth/gmail.modify"
  @login_scope "email profile #{@gmail_scope}"
  @login_session_key :google_login_session_params
  @oauth_action_key :google_oauth_action

  def request(conn, %{"provider" => "google"}) do
    redirect_uri = url(~p"/users/oauth/google/callback")

    {prompt, action} =
      if conn.assigns[:current_scope] do
        {"consent select_account", "connect"}
      else
        {"consent", "login"}
      end

    config =
      GoogleOAuth.config(
        redirect_uri: redirect_uri,
        authorization_params:
          GoogleOAuth.authorization_params(@login_scope,
            access_type: "offline",
            prompt: prompt
          )
      )

    case GoogleOAuth.authorize_url(config) do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(@login_session_key, session_params)
        |> put_session(@oauth_action_key, action)
        |> redirect(external: url)

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to authorize with Google")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(conn, %{"provider" => "google", "code" => _code} = params) do
    redirect_uri = url(~p"/users/oauth/google/callback")

    case get_session(conn, @login_session_key) do
      nil ->
        conn
        |> put_flash(:error, "Your Google session expired. Please try again.")
        |> redirect(to: ~p"/users/log-in")

      session_params ->
        action = get_session(conn, @oauth_action_key)

        conn =
          conn
          |> delete_session(@login_session_key)
          |> delete_session(@oauth_action_key)

        config =
          GoogleOAuth.config(
            redirect_uri: redirect_uri,
            authorization_params: GoogleOAuth.authorization_params(@login_scope),
            session_params: session_params
          )

        case GoogleOAuth.callback(config, params) do
          {:ok, %{user: google_user, token: token}} ->
            email = google_user["email"]

            if action == "connect" and conn.assigns[:current_scope] do
              handle_connect(conn, email, token)
            else
              handle_login(conn, google_user, token)
            end

          {:error, error} ->
            Logger.error("Google OAuth callback failed: #{inspect(error)}")

            conn
            |> put_flash(:error, "Failed to authenticate with Google")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  def callback(conn, %{"provider" => "google"}) do
    conn
    |> put_flash(:error, "Authentication with Google was cancelled")
    |> redirect(to: ~p"/users/log-in")
  end

  defp handle_connect(conn, email, token) do
    scope = conn.assigns[:current_scope]

    case create_email_account(scope.user, email, token) do
      {:ok, _email_account} ->
        conn
        |> put_flash(:info, "Successfully connected your Gmail account")
        |> redirect(to: ~p"/")

      {:error, error} ->
        Logger.error("Failed to connect Gmail account: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to connect your Gmail account")
        |> redirect(to: ~p"/")
    end
  end

  defp handle_login(conn, google_user, token) do
    email = google_user["email"]
    name = google_user["name"]

    case Accounts.get_user_by_email(email) do
      nil ->
        case Accounts.register_user(%{
               email: email,
               password: random_password(),
               full_name: name
             }) do
          {:ok, user} ->
            create_email_account(user, email, token)

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
  end

  defp random_password do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
  end

  defp create_email_account(user, email, token) do
    access_token = token["access_token"]
    refresh_token = token["refresh_token"]
    expires_in = token["expires_in"]
    token_type = token["token_type"]
    scopes = token["scope"] |> String.split(" ")

    expires_at =
      DateTime.add(DateTime.utc_now(), expires_in, :second)

    email_account_attrs = %{
      user_id: user.id,
      provider: "gmail",
      email: email,
      access_token: Encryption.encrypt(access_token),
      refresh_token: Encryption.encrypt(refresh_token),
      expires_at: expires_at,
      token_type: token_type,
      scopes: scopes
    }

    Gmail.create_email_account(email_account_attrs)
  end
end
