defmodule DevRound.Hosting do
  @moduledoc """
  The Sessions context.
  """

  import Ecto.Query, warn: false
  alias DevRound.Events.EventAttendee
  alias DevRound.Repo

  alias DevRound.Hosting.TeamName

  @doc """
  Returns the list of team_names.

  ## Examples

      iex> list_team_names()
      [%TeamName{}, ...]

  """
  def list_team_names do
    Repo.all(TeamName)
  end

  @doc """
  Gets a single team_name.

  Raises `Ecto.NoResultsError` if the Team name does not exist.

  ## Examples

      iex> get_team_name!(123)
      %TeamName{}

      iex> get_team_name!(456)
      ** (Ecto.NoResultsError)

  """
  def get_team_name!(id), do: Repo.get!(TeamName, id)

  @doc """
  Creates a team_name.

  ## Examples

      iex> create_team_name(%{field: value})
      {:ok, %TeamName{}}

      iex> create_team_name(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_team_name(attrs \\ %{}) do
    %TeamName{}
    |> TeamName.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a team_name.

  ## Examples

      iex> update_team_name(team_name, %{field: new_value})
      {:ok, %TeamName{}}

      iex> update_team_name(team_name, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_team_name(%TeamName{} = team_name, attrs) do
    team_name
    |> TeamName.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team_name.

  ## Examples

      iex> delete_team_name(team_name)
      {:ok, %TeamName{}}

      iex> delete_team_name(team_name)
      {:error, %Ecto.Changeset{}}

  """
  def delete_team_name(%TeamName{} = team_name) do
    Repo.delete(team_name)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team_name changes.

  ## Examples

      iex> change_team_name(team_name)
      %Ecto.Changeset{data: %TeamName{}}

  """
  def change_team_name(%TeamName{} = team_name, attrs \\ %{}) do
    TeamName.changeset(team_name, attrs)
  end

  def update_event_attendee_checked(%EventAttendee{} = attendee, checked) do
    attendee
    |> EventAttendee.check_changeset(%{checked: checked})
    |> Repo.update()
  end

  def change_event_attendee_checked(%EventAttendee{} = attendee, checked) do
    EventAttendee.check_changeset(attendee, %{checked: checked})
  end

  def validate_team_generation_constraints(attendees) do
    attendees = filter_checked(attendees)

    if Enum.count(attendees) >= 2 do
      messages =
        for attendee <- attendees do
          potential_team_mates =
            Enum.filter(attendees, fn other ->
              attendee != other && are_compatible?(attendee, other)
            end)

          if Enum.empty?(potential_team_mates) do
            "No team mate for #{attendee.user.full_name} available wrt. remote status and selected languages."
          else
            nil
          end
        end
        |> Enum.reject(&is_nil/1)

      case messages do
        [] -> {:ok, []}
        _ -> {:error, messages}
      end
    else
      {:error, ["Not enough checked participants to build teams."]}
    end
  end

  defp filter_checked(attendees) do
    Enum.filter(attendees, fn a -> a.checked end)
  end

  defp are_compatible?(%EventAttendee{} = a, %EventAttendee{} = b) do
    a.is_remote == b.is_remote and not MapSet.disjoint?(MapSet.new(a.langs), MapSet.new(b.langs))
  end
end
