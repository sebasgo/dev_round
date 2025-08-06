defmodule DevRound.Repo.Migrations.AddLocalDatesToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :begin_local, :naive_datetime, null: false
      add :end_local, :naive_datetime, null: false
      add :registration_deadline_local, :naive_datetime, null: false
    end
  end
end
