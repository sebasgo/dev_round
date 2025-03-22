defmodule DevRound.Repo.Migrations.CreateEventAttendeesLangs do
  use Ecto.Migration

  def change do
    create table(:event_attendees_langs) do
      add :event_attendee_id, references(:event_attendees, on_delete: :delete_all)
      add :lang_id, references(:langs, on_delete: :delete_all)
    end

    create unique_index(:event_attendees_langs, [:event_attendee_id, :lang_id])
  end
end
