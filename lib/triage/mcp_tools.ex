defmodule Triage.MCPTools do
  @moduledoc """
  MCP tools integration for LangChain using LangChain.MCP.Adapter.
  """

  alias LangChain.MCP.Adapter
  require Logger

  @doc """
  Converts MCP tools from PlaywrightMCP client to LangChain functions.
  """
  def to_functions do
    case Process.whereis(Triage.PlaywrightMCP) do
      nil ->
        Logger.warning("PlaywrightMCP not available")
        []

      _pid ->
        Logger.debug("PlaywrightMCP is running, creating adapter")

        adapter =
          Adapter.new(
            client: Triage.PlaywrightMCP,
            cache_tools: false,
            context: %{}
          )

        Logger.debug("Calling Adapter.to_functions")
        functions = Adapter.to_functions(adapter)

        # Fix: ensure context defaults to %{} instead of nil
        functions =
          Enum.map(functions, fn fn_struct ->
            %{
              fn_struct
              | function: fn args, context ->
                  fn_struct.function.(args, context || %{})
                end
            }
          end)

        Logger.info("Loaded #{length(functions)} MCP tools")
        functions
    end
  end
end
