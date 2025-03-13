defmodule DevRound.Repo.Migrations.CreateEventLangs do
  use Ecto.Migration

  def change do
    create table(:event_langs) do
      add :name, :string
      add :icon_path, :string

      timestamps(type: :utc_datetime)
    end
  end
end
