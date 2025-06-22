defmodule DevRound.Repo.Migrations.AddCheckedToEventAttendees do
  use Ecto.Migration

  def change do
    alter table(:event_attendees) do
      add :checked, :boolean, default: false, null: false
    end

  end
end
