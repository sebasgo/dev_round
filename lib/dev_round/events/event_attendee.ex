defmodule DevRound.Events.EventAttendee do
  @moduledoc """
  Event attendee schema for tracking user registration and participation.

  Links users to events with registration details including remote status,
  experience level, and check-in status.
  """

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

  @doc false
  def changeset(event_attendee, attrs, _opts \\ %{}) do
    event_attendee
    |> cast(attrs, [:event_id, :user_id, :is_remote, :experience_level])
    |> validate_required([:is_remote, :user_id, :event_id])
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
    |> cast(attrs, [:is_remote, :experience_level, :user_id])
    |> validate_experience_level()
    |> validate_user_selected()
  end

  def check_changeset(event_attendee, attrs) do
    event_attendee
    |> cast(attrs, [:checked])
    |> validate_required([:checked])
  end

  defp validate_user_selected(changeset) do
    if is_nil(get_field(changeset, :user_id)) and is_nil(get_field(changeset, :user)) do
      add_error(changeset, :user_id, "Please select a participant.")
    else
      changeset
    end
  end
end
