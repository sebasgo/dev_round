defmodule DevRound.EventsTest do
  use DevRound.DataCase

  alias DevRound.Events

  describe "events" do
    alias DevRound.Events.Event

    import DevRound.EventsFixtures

    @invalid_attrs %{title: nil, location: nil, begin: nil, end: nil, body: nil, published: nil}

    test "list_events/0 returns all events" do
      event = event_fixture()
      assert Events.list_events() == [event]
    end

    test "get_event!/1 returns the event with given id" do
      event = event_fixture()
      assert Events.get_event!(event.id) == event
    end

    test "create_event/1 with valid data creates a event" do
      valid_attrs = %{
        title: "some title",
        location: "some location",
        begin: ~U[2025-03-14 16:12:00Z],
        end: ~U[2025-03-14 16:12:00Z],
        body: "some body",
        published: true
      }

      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs)
      assert event.title == "some title"
      assert event.location == "some location"
      assert event.begin == ~U[2025-03-14 16:12:00Z]
      assert event.end == ~U[2025-03-14 16:12:00Z]
      assert event.body == "some body"
      assert event.published == true
    end

    test "create_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(@invalid_attrs)
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()

      update_attrs = %{
        title: "some updated title",
        location: "some updated location",
        begin: ~U[2025-03-15 16:12:00Z],
        end: ~U[2025-03-15 16:12:00Z],
        body: "some updated body",
        published: false
      }

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.title == "some updated title"
      assert event.location == "some updated location"
      assert event.begin == ~U[2025-03-15 16:12:00Z]
      assert event.end == ~U[2025-03-15 16:12:00Z]
      assert event.body == "some updated body"
      assert event.published == false
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, @invalid_attrs)
      assert event == Events.get_event!(event.id)
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end

  describe "event_session" do
    alias DevRound.Events.EventSession

    import DevRound.EventsFixtures

    @invalid_attrs %{
      title: nil,
      begin: nil,
      end: nil,
      slug: nil,
      begin_local: nil,
      end_local: nil
    }

    test "list_event_session/0 returns all event_session" do
      event_session = event_session_fixture()
      assert Events.list_event_session() == [event_session]
    end

    test "get_event_session!/1 returns the event_session with given id" do
      event_session = event_session_fixture()
      assert Events.get_event_session!(event_session.id) == event_session
    end

    test "create_event_session/1 with valid data creates a event_session" do
      valid_attrs = %{
        title: "some title",
        begin: ~U[2025-07-23 19:04:00Z],
        end: ~U[2025-07-23 19:04:00Z],
        slug: "some slug",
        begin_local: ~N[2025-07-23 19:04:00],
        end_local: ~N[2025-07-23 19:04:00]
      }

      assert {:ok, %EventSession{} = event_session} = Events.create_event_session(valid_attrs)
      assert event_session.title == "some title"
      assert event_session.begin == ~U[2025-07-23 19:04:00Z]
      assert event_session.end == ~U[2025-07-23 19:04:00Z]
      assert event_session.slug == "some slug"
      assert event_session.begin_local == ~N[2025-07-23 19:04:00]
      assert event_session.end_local == ~N[2025-07-23 19:04:00]
    end

    test "create_event_session/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event_session(@invalid_attrs)
    end

    test "update_event_session/2 with valid data updates the event_session" do
      event_session = event_session_fixture()

      update_attrs = %{
        title: "some updated title",
        begin: ~U[2025-07-24 19:04:00Z],
        end: ~U[2025-07-24 19:04:00Z],
        slug: "some updated slug",
        begin_local: ~N[2025-07-24 19:04:00],
        end_local: ~N[2025-07-24 19:04:00]
      }

      assert {:ok, %EventSession{} = event_session} =
               Events.update_event_session(event_session, update_attrs)

      assert event_session.title == "some updated title"
      assert event_session.begin == ~U[2025-07-24 19:04:00Z]
      assert event_session.end == ~U[2025-07-24 19:04:00Z]
      assert event_session.slug == "some updated slug"
      assert event_session.begin_local == ~N[2025-07-24 19:04:00]
      assert event_session.end_local == ~N[2025-07-24 19:04:00]
    end

    test "update_event_session/2 with invalid data returns error changeset" do
      event_session = event_session_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Events.update_event_session(event_session, @invalid_attrs)

      assert event_session == Events.get_event_session!(event_session.id)
    end

    test "delete_event_session/1 deletes the event_session" do
      event_session = event_session_fixture()
      assert {:ok, %EventSession{}} = Events.delete_event_session(event_session)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event_session!(event_session.id) end
    end

    test "change_event_session/1 returns a event_session changeset" do
      event_session = event_session_fixture()
      assert %Ecto.Changeset{} = Events.change_event_session(event_session)
    end
  end
end
