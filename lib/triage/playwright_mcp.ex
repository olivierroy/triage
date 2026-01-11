defmodule Triage.PlaywrightMCP do
  @moduledoc """
  MCP client for connecting to Playwright MCP server for browser automation.
  Uses Anubis.Client for proper MCP protocol handling.
  """
  use Anubis.Client,
    name: "Triage",
    version: "1.0.0",
    protocol_version: "2025-03-26",
    capabilities: []

  @doc """
  Helper for building transport options for the Playwright MCP client.

  Ensures the base URL is normalized for the streamable HTTP transport.
  """
  @spec transport_options(String.t()) :: keyword()
  def transport_options(base_url) when is_binary(base_url) do
    cleaned_url = String.trim_trailing(base_url, "/")

    [
      base_url: cleaned_url,
      recv_timeout: 120_000
    ]
  end
end
