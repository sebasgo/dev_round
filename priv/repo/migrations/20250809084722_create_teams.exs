defmodule DevRound.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :is_remote, :boolean, default: false, null: false
      add :session_id, references(:sessions, on_delete: :nothing)
      add :lang_id, references(:langs, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:teams, [:session_id])
    create index(:teams, [:lang_id])

    create table(:team_members) do
      add :team_id, references(:teams, on_delete: :delete_all)
      add :attendee_id, references(:event_attendees, on_delete: :delete_all)
    end

    create unique_index(:team_members, [:team_id, :attendee_id])
  end
end
