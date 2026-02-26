import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dev_round, DevRound.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "helloweb_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dev_round, DevRoundWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "bDwYi0303k7Ignjn1T+KvwjfciQXU+/ZHZfKefyifSSdwFGLwqPVyfTnlKmmxFT6",
  server: false

# Enable dev routes (important to avoid compiler warnings during test builds)
config :dev_round, dev_routes: true

# In test we don't send emails
config :dev_round, DevRound.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
