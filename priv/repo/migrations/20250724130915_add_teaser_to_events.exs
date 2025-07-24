defmodule DevRound.Repo.Migrations.AddTeaserToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :teaser, :string, default: "", null: false
    end
  end
end
