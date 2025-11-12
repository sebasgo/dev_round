defmodule DevRound.Repo.Migrations.AddFlagsToEventSessions do
  use Ecto.Migration

  def change do
    alter table(:event_sessions) do
      add :live, :boolean, null: false, default: false
      add :teams_locked, :boolean, null: false, default: false
    end
  end
end
