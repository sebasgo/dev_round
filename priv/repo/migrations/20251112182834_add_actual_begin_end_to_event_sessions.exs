defmodule DevRound.Repo.Migrations.AddActualBeginEndToEventSessions do
  use Ecto.Migration

  def change do
    alter table(:event_sessions) do
      add :actual_begin, :utc_datetime, null: true
      add :actual_end, :utc_datetime, null: true
    end
  end
end
