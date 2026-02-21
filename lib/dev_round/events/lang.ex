defmodule DevRound.Events.Lang do
  @moduledoc """
  Programming language schema for events.

  Represents programming languages used in events, with associated
  icons and team assignments.
  """

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
    |> validate_change(:icon_path, fn :icon_path, path ->
      case path do
        "too_many_files" -> [icon_path: "Only one icon is allowed."]
        "" -> [icon_path: "Required."]
        _ -> []
      end
    end)
  end
end
