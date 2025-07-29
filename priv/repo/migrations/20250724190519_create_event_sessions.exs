defmodule DevRound.Repo.Migrations.CreateEventSessions do
  use Ecto.Migration

  def change do
    create table(:event_sessions) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :begin, :utc_datetime, null: false
      add :begin_local, :naive_datetime, null: false
      add :end, :utc_datetime, null: false
      add :end_local, :naive_datetime, null: false
      add :event_id, references(:events, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:event_sessions, [:slug])
  end
end
