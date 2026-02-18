defmodule DevRound.Events.EventHost do
  use Ecto.Schema
  import Ecto.Changeset

  alias DevRound.Accounts.User
  alias DevRound.Events.Event

  @primary_key false
  schema "event_hosts" do
    field :position, :integer
    belongs_to :event, Event, primary_key: true
    belongs_to :user, User, primary_key: true
  end

  def changeset(event_host, attrs, position) do
    event_host
    |> cast(attrs, [:event_id, :user_id])
    |> change(position: position)
    |> unique_constraint([:event, :user],
      name: "event_hosts_event_id_user_id_index",
      message: "User is already an host for this event"
    )
  end
end
