defmodule DevRound.Events.Lang do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_langs" do
    field :name, :string
    field :icon_path, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lang, attrs, _opts \\ %{}) do
    lang
    |> cast(attrs, [:name, :icon_path])
    |> validate_required([:name, :icon_path])
  end
end
