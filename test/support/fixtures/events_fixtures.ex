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

  @doc """
  Generate a event_session.
  """
  def event_session_fixture(attrs \\ %{}) do
    {:ok, event_session} =
      attrs
      |> Enum.into(%{
        begin: ~U[2025-07-23 19:04:00Z],
        begin_local: ~N[2025-07-23 19:04:00],
        end: ~U[2025-07-23 19:04:00Z],
        end_local: ~N[2025-07-23 19:04:00],
        slug: "some slug",
        title: "some title"
      })
      |> DevRound.Events.create_event_session()

    event_session
  end

  @doc """
  Generate a lang.
  """
  def lang_fixture(attrs \\ %{}) do
    {:ok, lang} =
      attrs
      |> Enum.into(%{
        name: "some name",
        icon_path: "elixir.png"
      })
      |> DevRound.Events.create_lang()

    lang
  end
end
