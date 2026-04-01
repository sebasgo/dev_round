defmodule DevRound.HostingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DevRound.Hosting` context.
  """

  @doc """
  Generate a team_name.
  """
  def team_name_fixture(attrs \\ %{}) do
    {:ok, team_name} =
      attrs
      |> Enum.into(%{
        name: "some name #{System.unique_integer()}"
      })
      |> DevRound.Hosting.create_team_name()

    team_name
  end
end
