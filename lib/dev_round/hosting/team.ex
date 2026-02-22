defmodule DevRound.Hosting.Team do
  @moduledoc """
  Team schema for hosting team formation during events.

  Represents teams formed during event sessions. Team members are stored
  as snapshots of attendee data at team formation time, decoupled from
  live registration records.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias DevRound.Events.EventSession
  alias DevRound.Events.Lang
  alias DevRound.Hosting.TeamMember

  schema "teams" do
    field :name, :string
    field :slug, :string
    field :is_remote, :boolean, default: false

    belongs_to :session, EventSession
    belongs_to :lang, Lang
    has_many :members, TeamMember, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :slug, :is_remote])
    |> validate_required([:name, :slug, :is_remote])
  end
end
