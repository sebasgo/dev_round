defmodule DevRound.Sessions do
  @moduledoc """
  The Sessions context.
  """

  import Ecto.Query, warn: false
  alias DevRound.Repo

  alias DevRound.Sessions.TeamName

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
end
