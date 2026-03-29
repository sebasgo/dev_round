defmodule DevRound.Events.TeamVideoConferenceRoom do
  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Changeset
  alias DevRound.Events.Event

  schema "team_video_conference_rooms" do
    field :url, :string
    belongs_to :event, Event
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:url])
    |> validate_required([:url])
    |> validate_http_url(:url)
  end
end
