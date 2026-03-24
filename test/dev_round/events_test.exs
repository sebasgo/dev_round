defmodule DevRound.EventsTest do
  use DevRound.DataCase

  alias DevRound.Events
  alias DevRound.Events.Event
  alias DevRound.Events.EventSession
  alias DevRound.Events.Lang
  alias DevRound.Events.EventAttendee

  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  describe "list_events/0" do
    test "returns all events" do
      event1 = event_fixture()
      event2 = event_fixture()
      events = Events.list_events()
      assert Enum.any?(events, fn e -> e.id == event1.id end)
      assert Enum.any?(events, fn e -> e.id == event2.id end)
    end
  end

  describe "list_events/1" do
    test "returns current events in ascending order" do
      now = NaiveDateTime.local_now()
      e1_begin = NaiveDateTime.add(now, 1, :day) |> NaiveDateTime.truncate(:second)
      e2_begin = NaiveDateTime.add(now, 2, :day) |> NaiveDateTime.truncate(:second)

      event1 = event_fixture(%{begin_local: e1_begin})
      event2 = event_fixture(%{begin_local: e2_begin})

      events = Events.list_events(:current)

      assert Enum.find_index(events, &(&1.id == event1.id)) <
               Enum.find_index(events, &(&1.id == event2.id))
    end

    test "returns archived events in descending order" do
      now = NaiveDateTime.local_now()
      e1_begin = NaiveDateTime.add(now, -3, :day) |> NaiveDateTime.truncate(:second)
      e2_begin = NaiveDateTime.add(now, -2, :day) |> NaiveDateTime.truncate(:second)

      event1 = event_fixture(%{begin_local: e1_begin})
      event2 = event_fixture(%{begin_local: e2_begin})

      events = Events.list_events(:archived)

      assert Enum.find_index(events, &(&1.id == event2.id)) <
               Enum.find_index(events, &(&1.id == event1.id))
    end

    test "does not return unpublished events" do
      event_fixture(%{published: false})
      assert Events.list_events(:current) == []
    end

    test "list_registered_events_for_user/1 returns registered events" do
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      user = user_fixture()

      {:ok, _attendee} =
        Events.create_event_attendee(event, user, %{
          "lang_ids" => [Enum.at(event.langs, 0).id]
        })

      registered_events = Events.list_registered_events_for_user(user.id)
      assert length(registered_events) == 1
      assert hd(registered_events).id == event.id
      assert hd(registered_events).sessions != []
      assert hd(registered_events).langs != []
    end
  end

  describe "get_event!" do
    test "returns the event with given id" do
      event = event_fixture()
      assert Events.get_event!(event.id).id == event.id
    end

    test "returns the event with given slug" do
      event = event_fixture()
      assert Events.get_event!(event.slug).id == event.id
    end

    test "raises Ecto.NoResultsError if event does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(-1) end
    end

    test "raises Ecto.NoResultsError if event is unpublished" do
      event = event_fixture(%{published: false})
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end
  end

  describe "create_event/1" do
    test "creates an event with valid data" do
      host = user_fixture()
      lang = lang_fixture()
      now = NaiveDateTime.local_now()
      begin = NaiveDateTime.add(now, 1, :day) |> NaiveDateTime.truncate(:second)

      attrs = %{
        title: "New Event",
        teaser: "T",
        body: "B",
        location: "L",
        begin_local: begin,
        end_local: NaiveDateTime.add(begin, 1, :day),
        registration_deadline_local: NaiveDateTime.add(begin, -1, :hour),
        published: true,
        event_hosts: [%{user_id: host.id}],
        sessions: [
          %{title: "S1", begin_local: begin, end_local: NaiveDateTime.add(begin, 1, :hour)}
        ]
      }

      assert {:ok, %Event{} = event} = Events.create_event(attrs, put_langs: [lang])
      assert event.title == "New Event"
    end

    test "returns error with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(%{})
    end
  end

  describe "update_event/2" do
    test "updates the event" do
      event = event_fixture()
      assert {:ok, %Event{} = updated_event} = Events.update_event(event, %{title: "Updated"})
      assert updated_event.title == "Updated"
    end

    test "returns error with invalid data" do
      event = event_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{title: nil})
    end
  end

  describe "delete_event/1" do
    test "deletes the event" do
      event = event_fixture()
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end
  end

  describe "change_event/2" do
    test "returns a changeset for the event" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end

    test "validates registration deadline is before begin" do
      event = event_fixture()
      invalid_deadline = NaiveDateTime.add(event.begin_local, 1, :hour)
      changeset = Events.change_event(event, %{"registration_deadline_local" => invalid_deadline})
      assert %{registration_deadline_local: ["Must be before begin."]} = errors_on(changeset)
    end

    test "validates sessions are within event dates" do
      event = event_fixture()
      invalid_session_begin = NaiveDateTime.add(event.begin_local, -1, :hour)

      attrs = %{
        "sessions" => %{
          "0" => %{
            "title" => "XS",
            "begin_local" => invalid_session_begin,
            "end_local" => event.end_local
          }
        }
      }

      changeset = Events.change_event(event, attrs)
      assert %{sessions: ["XS must begin after or with event."]} = errors_on(changeset)
    end

    test "validates sessions do not overlap" do
      event = event_fixture()

      attrs = %{
        "sessions" => %{
          "0" => %{
            "title" => "S1",
            "begin_local" => event.begin_local,
            "end_local" => NaiveDateTime.add(event.begin_local, 90, :minute)
          },
          "1" => %{
            "title" => "S2",
            "begin_local" => NaiveDateTime.add(event.begin_local, 1, :hour),
            "end_local" => event.end_local
          }
        }
      }

      changeset = Events.change_event(event, attrs)
      assert %{sessions: ["S1 overlaps with S2."]} = errors_on(changeset)
    end

    test "requires at least one lang" do
      event = event_fixture()

      changeset =
        event
        |> Repo.preload(:langs)
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:langs, [])
        |> DevRound.Changeset.validate_option_selected([:langs])

      assert %{langs: ["Required."]} = errors_on(changeset)
    end
  end

  describe "update_event_slides_page_number/2" do
    test "updates page number" do
      event = event_fixture()

      assert {:ok, %Event{} = event} =
               Events.update_event_slides_page_number(event, %{slides_page_number: 5})

      assert event.slides_page_number == 5
    end
  end

  describe "update_event_live/2" do
    test "updates live status" do
      event = event_fixture()
      assert {:ok, %Event{} = event} = Events.update_event_live(event, true)
      assert event.live == true
    end
  end

  describe "get_event_pdf_url/1" do
    test "returns correct URL for slides" do
      event = event_fixture(%{slides_filename: "test.pdf"})
      assert Events.get_event_pdf_url(event) =~ "/uploads/events/slides/test.pdf"
    end

    test "returns nil when no slides_filename" do
      event = event_fixture(%{slides_filename: nil})
      assert is_nil(Events.get_event_pdf_url(event))
    end
  end

  describe "create_lang/1" do
    test "creates a lang with valid data" do
      attrs = %{name: "Python", icon_path: "python.svg"}
      assert {:ok, %Lang{}} = Events.create_lang(attrs)
    end

    test "does not create a lang with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Events.create_lang(%{})
    end
  end

  describe "change_lang/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Events.change_lang(%Lang{})
    end
  end

  describe "lang_icon_dir/0 and event_slides_dir/0" do
    test "returns correct paths" do
      assert Events.lang_icon_dir() == Path.join(["uploads", "langs", "icon"])
      assert Events.event_slides_dir() == Path.join(["uploads", "events", "slides"])
    end
  end

  describe "event_open_for_registration?/1" do
    test "returns true when deadline is in the future" do
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      assert Events.event_open_for_registration?(event)
    end

    test "returns false when deadline is in the past" do
      event =
        event_fixture(%{
          registration_deadline_local: NaiveDateTime.add(NaiveDateTime.local_now(), -1, :day)
        })

      assert Events.event_open_for_registration?(event) == false
    end
  end

  describe "change_event_attendee/4" do
    test "applies custom validation logic" do
      event = event_fixture()
      other_lang = lang_fixture()

      # Valid
      assert Events.change_event_attendee(
               %EventAttendee{},
               event,
               %{"lang_ids" => [Enum.at(event.langs, 0).id]},
               :self_registration
             ).valid?

      # Missing
      assert %{lang_ids: ["Please select at least one language."]} =
               errors_on(
                 Events.change_event_attendee(
                   %EventAttendee{},
                   event,
                   %{"lang_ids" => []},
                   :self_registration
                 )
               )

      # Invalid for event
      assert %{lang_ids: ["Invalid language for this event."]} =
               errors_on(
                 Events.change_event_attendee(
                   %EventAttendee{},
                   event,
                   %{"lang_ids" => [other_lang.id]},
                   :self_registration
                 )
               )
    end
  end

  describe "event_has_multiple_langs?/1" do
    test "returns false for one language" do
      event = event_fixture() |> Repo.preload(:langs)
      refute Events.event_has_multiple_langs?(event)
    end

    test "returns true for multiple languages" do
      lang1 = lang_fixture()
      lang2 = lang_fixture()
      event = event_fixture(%{put_langs: [lang1, lang2]}) |> Repo.preload(:langs)
      assert Events.event_has_multiple_langs?(event)
    end
  end

  describe "create_event_attendee/4" do
    test "creates attendee when registration is open" do
      user = user_fixture()
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      attrs = %{"lang_ids" => [Enum.at(event.langs, 0).id]}
      assert {:ok, %EventAttendee{}} = Events.create_event_attendee(event, user, attrs)
    end

    test "returns error when registration is closed" do
      user = user_fixture()
      past_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), -1, :day)
      event = event_fixture(%{registration_deadline_local: past_deadline})
      assert {:error, :registration_closed} = Events.create_event_attendee(event, user, %{})
    end
  end

  describe "update_event_attendee/3" do
    test "updates attendee" do
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      user = user_fixture()

      {:ok, attendee} =
        Events.create_event_attendee(event, user, %{"lang_ids" => [Enum.at(event.langs, 0).id]})

      assert {:ok, %EventAttendee{is_remote: true}} =
               Events.update_event_attendee(attendee, %{is_remote: true})
    end
  end

  describe "delete_event_attendee/2" do
    test "deletes attendee" do
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      user = user_fixture()

      {:ok, attendee} =
        Events.create_event_attendee(event, user, %{"lang_ids" => [Enum.at(event.langs, 0).id]})

      assert {:ok, %EventAttendee{}} = Events.delete_event_attendee(attendee)
    end
  end

  describe "list_langs_by_id/1" do
    test "returns langs for given ids" do
      lang = lang_fixture()
      assert Events.list_langs_by_id([lang.id]) == [lang]
    end
  end

  describe "get_lang_by_name/1" do
    test "returns lang by name" do
      lang = lang_fixture(%{name: "Unique"})
      assert Events.get_lang_by_name("Unique").id == lang.id
    end
  end

  describe "get_lang!/1" do
    test "returns lang by id" do
      lang = lang_fixture()
      assert Events.get_lang!(lang.id).id == lang.id
    end
  end

  describe "list_event_session/0" do
    test "returns all sessions" do
      event = event_fixture()
      session = Enum.at(event.sessions, 0)
      assert Enum.any?(Repo.all(EventSession), &(&1.id == session.id))
    end
  end

  describe "get_event_session!/1" do
    test "returns session by id" do
      event = event_fixture()
      session = Enum.at(event.sessions, 0)
      assert Events.get_event_session!(session.id).id == session.id
    end
  end

  describe "create_event_session/1" do
    test "creates session with manual event_id" do
      event = event_fixture()
      attrs = %{title: "New", begin_local: event.begin_local, end_local: event.end_local}

      assert {:ok, session} =
               %EventSession{}
               |> Ecto.Changeset.change(%{event_id: event.id})
               |> EventSession.changeset(attrs)
               |> Repo.insert()

      assert session.event_id == event.id
    end
  end

  describe "update_event_session/2" do
    test "updates session" do
      event = event_fixture()
      session = Enum.at(event.sessions, 0)

      assert {:ok, session} =
               session
               |> EventSession.changeset(%{title: "Up"})
               |> Repo.update()

      assert session.title == "Up"
    end
  end

  describe "start_event_session/2" do
    test "starts session and stops previous one" do
      event =
        event_fixture(%{
          sessions: [
            %{
              title: "S1",
              begin_local: ~N[2026-01-01 10:00:00],
              end_local: ~N[2026-01-01 11:00:00]
            },
            %{
              title: "S2",
              begin_local: ~N[2026-01-01 11:00:00],
              end_local: ~N[2026-01-01 12:00:00]
            }
          ],
          begin_local: ~N[2026-01-01 10:00:00],
          end_local: ~N[2026-01-01 12:00:00]
        })

      event = Events.get_event!(event.id) |> Repo.preload(:last_live_session)
      [s1, s2] = event.sessions

      {:ok, %{session: s1, event: event}} = Events.start_event_session(event, s1)
      assert s1.live
      assert event.last_live_session_id == s1.id

      # Must preload for next call as well if we pass current event
      event = Events.get_event!(event.id) |> Repo.preload(:last_live_session)
      {:ok, %{session: s2}} = Events.start_event_session(event, s2)
      assert s2.live
      refute Events.get_event_session!(s1.id).live
    end
  end

  describe "stop_event_session/1" do
    test "stops live session" do
      event = event_fixture() |> Repo.preload(:last_live_session)
      session = Enum.at(event.sessions, 0)
      {:ok, %{session: session}} = Events.start_event_session(event, session)
      assert {:ok, %EventSession{live: false}} = Events.stop_event_session(session)
    end
  end

  describe "reset_event_session/1" do
    test "resets session state" do
      event = event_fixture() |> Repo.preload(:last_live_session)
      session = Enum.at(event.sessions, 0)
      {:ok, %{session: session}} = Events.start_event_session(event, session)
      assert {:ok, %EventSession{actual_begin: nil}} = Events.reset_event_session(session)
    end
  end

  describe "delete_event_session/1" do
    test "deletes session" do
      event = event_fixture()
      session = Enum.at(event.sessions, 0)
      assert {:ok, %EventSession{}} = Events.delete_event_session(session)
    end
  end

  describe "change_event_session/2" do
    test "returns changeset" do
      session = Enum.at(event_fixture().sessions, 0)
      assert %Ecto.Changeset{} = Events.change_event_session(session)
    end
  end
end
