defmodule Triage.Gmail.AITest do
  use Triage.DataCase, async: true

  # No longer testing fallback parsing as we switched to JSON mode
  # But we can add it back if we want to confirm the AI module works as expected
  # with mocked responses.
end
