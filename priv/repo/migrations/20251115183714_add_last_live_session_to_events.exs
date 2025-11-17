defmodule DevRound.Repo.Migrations.AddLastLiveSessionToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :last_live_session_id, references(:event_sessions, on_delete: :nilify_all)
    end
  end
end
