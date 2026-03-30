defmodule DevRound.Repo.Migrations.AddVideoConferenceRooms do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :main_video_conference_room_url, :string
    end

    alter table(:teams) do
      add :video_conference_room_url, :string
    end

    create table(:team_video_conference_rooms) do
      add :url, :string, null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
    end

    create index(:team_video_conference_rooms, [:event_id])
  end
end
