defmodule DevRound.Events.Lang do
  use Ecto.Schema
  import Ecto.Changeset
  alias DevRound.Hosting.Team

  schema "langs" do
    field :name, :string
    field :icon_path, :string

    has_many :teams, Team, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lang, attrs, _opts \\ %{}) do
    lang
    |> cast(attrs, [:name, :icon_path])
    |> validate_required([:name, :icon_path])
  end
end
