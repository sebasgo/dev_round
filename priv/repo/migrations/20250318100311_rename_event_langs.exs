defmodule DevRound.Repo.Migrations.RenameEventLangs do
  use Ecto.Migration

  def change do
    rename table("event_langs"), to: table("langs")
  end
end
