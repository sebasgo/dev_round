defmodule DevRound.Repo.Migrations.AddUserAvatarField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :avatar_url, :string, null: true
      add :avatar, :binary, null: true
    end
  end
end
