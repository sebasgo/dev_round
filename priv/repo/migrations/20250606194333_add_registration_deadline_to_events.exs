defmodule DevRound.Repo.Migrations.AddRegistrationDeadlineToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :registration_deadline, :utc_datetime, null: false
    end
  end
end
