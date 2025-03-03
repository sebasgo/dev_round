defmodule DevRound.Repo do
  use Ecto.Repo,
    otp_app: :dev_round,
    adapter: Ecto.Adapters.SQLite3
end
