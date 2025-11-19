defmodule DevRound.Repo.Migrations.AddModifiedAtToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :modified_at, :utc_datetime
    end

    execute("UPDATE events SET modified_at = updated_at", "UPDATE events SET modified_at = NULL")

    alter table(:events) do
      modify :modified_at, :utc_datetime, null: false, from: {:utc_datetime, null: true}
    end
  end
end
