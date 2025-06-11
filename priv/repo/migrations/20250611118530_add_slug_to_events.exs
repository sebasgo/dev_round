defmodule DevRound.Repo.Migrations.AddSlugToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :slug, :string
    end

    create unique_index(:events, [:slug])
  end
end
