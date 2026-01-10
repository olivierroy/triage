ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Triage.Repo, :manual)

Mox.defmock(Triage.Gmail.ClientMock, for: Triage.Gmail.ClientBehaviour)
Mox.defmock(Triage.Gmail.AIMock, for: Triage.Gmail.AIBehaviour)
