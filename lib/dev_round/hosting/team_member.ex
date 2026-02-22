defmodule DevRound.Hosting.TeamMember do
  @moduledoc """
  Team member schema for storing snapshot data of attendees at team formation time.

  Captures the attendee's state (remote status, experience level, languages)
  when teams are built, decoupling teams from live registration data. This ensures
  that changes to or cancellation of registrations do not affect established teams.
  The user association is kept for avatar and name display purposes.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias DevRound.Hosting.Team
  alias DevRound.Accounts.User
  alias DevRound.Events.Lang

  schema "team_members" do
    field :is_remote, :boolean, default: false
    field :experience_level, :integer

    belongs_to :team, Team
    belongs_to :user, User
    many_to_many :langs, Lang, join_through: "team_member_langs", on_replace: :delete
  end

  @doc false
  def changeset(team_member, attrs) do
    team_member
    |> cast(attrs, [:is_remote, :experience_level])
    |> validate_required([:is_remote, :experience_level])
  end
end
