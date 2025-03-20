defmodule DevRound.Repo.Migrations.CreateEventHostsAndAttendees do
  use Ecto.Migration

  def change do
    create table(:event_hosts, primary_key: false) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
    end

    create unique_index(:event_hosts, [:event_id, :user_id])

    create table(:event_attendees) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
      add :is_remote, :boolean, default: false, null: false
      add :expierence_level, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:event_attendees, [:event_id, :user_id])
  end
end
