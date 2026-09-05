defmodule DevRound.Repo.Migrations.AddAllowRemoteParticipationToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :allow_remote_participation, :boolean, null: false, default: true
    end
  end
end
