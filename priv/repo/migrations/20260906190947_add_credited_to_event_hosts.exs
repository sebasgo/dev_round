defmodule DevRound.Repo.Migrations.AddCreditedToEventHosts do
  use Ecto.Migration

  def change do
    alter table(:event_hosts) do
      add :credited, :boolean, default: true, null: false
    end
  end
end
