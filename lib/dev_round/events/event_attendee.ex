defmodule DevRound.Events.EventAttendee do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Changeset
  alias DevRound.Accounts.User
  alias DevRound.Events.Event
  alias DevRound.Events.Lang

  schema "event_attendees" do
    field :is_remote, :boolean
    field :experience_level, :integer, default: 0
    field :checked, :boolean, default: false

    belongs_to :event, Event
    belongs_to :user, User
    many_to_many :langs, Lang, join_through: "event_attendees_langs", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(event_attendee, attrs, _opts \\ %{}) do
    event_attendee
    |> cast(attrs, [:event_id, :user_id, :is_remote, :experience_level])
    |> unique_constraint([:event_id, :user_id], message: "User already registered for this event")
    |> validate_experience_level()
  end

  def registration_changeset(event_attendee, attrs, :self_registration = _mode) do
    event_attendee
    |> cast(attrs, [:is_remote])
    |> validate_experience_level()
  end

  def registration_changeset(event_attendee, attrs, :host = _mode) do
    event_attendee
    |> cast(attrs, [:is_remote, :experience_level])
    |> validate_experience_level()
  end

  def check_changeset(event_attendee, attrs) do
    event_attendee
    |> cast(attrs, [:checked])
  end
end
