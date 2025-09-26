defmodule DevRound.Repo.Migrations.AddLiveToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :live, :boolean, null: false, default: false
    end
  end
end
