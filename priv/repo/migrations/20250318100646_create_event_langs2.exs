defmodule DevRound.Repo.Migrations.CreateEventLangs2 do
  use Ecto.Migration

  def change do
    create table(:event_langs, primary_key: false) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :lang_id, references(:langs, on_delete: :delete_all)
    end

    create unique_index(:event_langs, [:event_id, :lang_id])
  end
end
