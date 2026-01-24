defmodule DevRound.Repo.Migrations.AddUserAvatarHashField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_hash, :binary, null: true
    end
  end
end
