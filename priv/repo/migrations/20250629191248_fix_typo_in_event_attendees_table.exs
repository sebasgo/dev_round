defmodule DevRound.Repo.Migrations.FixTypoInEventAttendeesTable do
  use Ecto.Migration

  def change do
    rename table(:event_attendees), :expierence_level, to: :experience_level
  end
end
