defmodule Triage.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TriageWeb.Telemetry,
      Triage.Vault,
      Triage.Repo,
      {DNSCluster, query: Application.get_env(:triage, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Triage.PubSub},
      Triage.Gmail.TokenManager,
      {Oban, Application.get_env(:triage, Oban)},
      TriageWeb.Endpoint
    ]

    # Optional: Playwright MCP client (started separately with transient restart)
    playwright_url = Application.get_env(:triage, :playwright_mcp_url, nil)

    mcp_children =
      if playwright_url do
        mcp_url = String.trim_trailing(playwright_url, "/") <> "/mcp"

        transport_opts = Triage.PlaywrightMCP.transport_options(mcp_url)

        [
          Supervisor.child_spec(
            {Triage.PlaywrightMCP, transport: {:streamable_http, transport_opts}},
            id: Triage.PlaywrightMCP,
            restart: :transient,
            shutdown: 5000
          )
        ]
      else
        []
      end

    children = children ++ mcp_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Triage.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TriageWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
