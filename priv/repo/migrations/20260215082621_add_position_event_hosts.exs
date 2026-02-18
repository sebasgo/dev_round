defmodule DevRound.Repo.Migrations.AddPositionEventHosts do
  use Ecto.Migration

  def change do
    alter table(:event_hosts) do
      add :position, :integer, null: false, default: 0
    end
  end
end
