defmodule DevRound.Repo.Migrations.RenameUserExperienceLevelColumn do
  use Ecto.Migration

  def change do
    rename table("users"), :expierence_level, to: :experience_level
  end
end
