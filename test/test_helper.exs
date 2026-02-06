ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(DevRound.Repo, :manual)

# Set up Mimic for LDAP mocking
Mimic.copy(DevRound.LDAP)
