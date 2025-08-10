defmodule DevRound.Hosting.Team do
  use Ecto.Schema
  import Ecto.Changeset
  alias DevRound.Events.EventSession
  alias DevRound.Events.EventAttendee
  alias DevRound.Events.Lang

  schema "teams" do
    field :name, :string
    field :slug, :string
    field :is_remote, :boolean, default: false

    belongs_to :session, EventSession
    belongs_to :lang, Lang
    many_to_many :attendees, EventAttendee, join_through: "team_members"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :slug, :is_remote])
    |> validate_required([:name, :slug, :is_remote])
  end
end
