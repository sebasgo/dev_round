defmodule DevRound.Repo.Migrations.CreateTeamNames do
  use Ecto.Migration

  def change do
    create table(:team_names) do
      add :name, :string
      add :slug, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_names, [:slug])
  end
end
