defmodule DevRound.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :title, :string
      add :body, :text
      add :begin, :utc_datetime
      add :end, :utc_datetime
      add :location, :string
      add :published, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
