defmodule DevRound.Repo.Migrations.AddSlidesFilenameToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :slides_filename, :string, null: true
    end
  end
end
