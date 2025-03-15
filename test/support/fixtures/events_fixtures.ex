defmodule DevRound.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DevRound.Events` context.
  """

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        begin: ~U[2025-03-14 16:12:00Z],
        body: "some body",
        end: ~U[2025-03-14 16:12:00Z],
        location: "some location",
        published: true,
        title: "some title"
      })
      |> DevRound.Events.create_event()

    event
  end
end
