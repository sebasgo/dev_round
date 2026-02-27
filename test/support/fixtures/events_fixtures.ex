defmodule DevRound.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DevRound.Events` context.
  """

  import DevRound.AccountsFixtures

  @doc """
  Generate a event.
  Now creates a VALID event with all required associations by default.
  """
  def event_fixture(attrs \\ %{}) do
    now = NaiveDateTime.local_now()

    begin_local =
      attrs[:begin_local] || NaiveDateTime.add(now, 1, :day) |> NaiveDateTime.truncate(:second)

    # Ensure dependencies exist if not provided
    host = attrs[:host] || user_fixture(%{name: "host-#{System.unique_integer()}"})
    lang = attrs[:lang] || lang_fixture(%{name: "lang-#{System.unique_integer()}"})

    default_attrs = %{
      title: "some title #{System.unique_integer()}",
      teaser: "some teaser",
      body: "some body",
      location: "some location",
      begin_local: begin_local,
      end_local: NaiveDateTime.add(begin_local, 2, :hour),
      registration_deadline_local: NaiveDateTime.add(begin_local, -1, :day),
      published: true,
      event_hosts: [%{user_id: host.id}],
      sessions: [
        %{
          title: "Session 1",
          begin_local: begin_local,
          end_local: NaiveDateTime.add(begin_local, 1, :hour)
        }
      ]
    }

    create_attrs = Map.merge(default_attrs, Map.delete(attrs, :put_langs))
    put_langs = attrs[:put_langs] || [lang]

    {:ok, event} = DevRound.Events.create_event(create_attrs, put_langs: put_langs)

    event
  end

  @doc """
  Generate a lang.
  """
  def lang_fixture(attrs \\ %{}) do
    {:ok, lang} =
      attrs
      |> Enum.into(%{
        name: "some name #{System.unique_integer()}",
        icon_path: "elixir.png"
      })
      |> DevRound.Events.create_lang()

    lang
  end
end
