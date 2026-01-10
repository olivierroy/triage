defmodule TriageWeb.Router do
  use TriageWeb, :router

  import TriageWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TriageWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug TriageWeb.Plugs.CSPPlug
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TriageWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
  end

  scope "/", TriageWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", TriageWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:triage, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TriageWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TriageWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", TriageWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    delete "/users/settings", UserSettingsController, :delete
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
    resources "/categories", CategoryController, only: [:new, :create, :edit, :update]
    resources "/email_rules", EmailRuleController, except: [:show]
    resources "/email_accounts", EmailAccountController, only: [:index, :edit, :update]
    live "/emails", EmailLive

    post "/users/gmail/disconnect/:id", GmailController, :disconnect
    post "/users/gmail/import/:id", GmailController, :import
  end

  scope "/", TriageWeb do
    pipe_through [:browser]

    get "/users/oauth/:provider/request", UserOAuthController, :request
    get "/users/oauth/:provider/callback", UserOAuthController, :callback
    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
