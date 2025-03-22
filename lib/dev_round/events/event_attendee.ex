defmodule DevRound.Events.EventAttendee do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias DevRound.Events.Event
  alias DevRound.Accounts.User

  schema "event_attendees" do
    field :is_remote, :boolean
    field :expierence_level, :integer, default: 0

    belongs_to :event, Event
    belongs_to :user, User
    many_to_many :langs, Lang, join_through: "event_attendees_langs", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(event_attendee, attrs,_opts \\ %{}) do
    event_attendee
    |> cast(attrs, [:event_id, :user_id, :is_remote, :expierence_level])
  end

end
