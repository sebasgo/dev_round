defmodule DevRound.Repo.Migrations.AddSlidesPageNumberToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :slides_page_number, :integer, null: false, default: 1
    end
  end
end
