defmodule DevRoundWeb.UserEventsLiveTest do
  use DevRoundWeb.ConnCase

  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures
  alias DevRound.Events

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "User Events" do
    test "renders empty state when no registrations", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/user/events")
      assert html =~ "No registrations found"
    end

    test "renders underway, upcoming and archived events with multi-day support", %{
      conn: conn,
      user: user
    } do
      tz = Application.get_env(:dev_round, :time_zone)
      {:ok, now} = DateTime.now(tz)

      # Underway: multi-day event starting yesterday, ending tomorrow
      begin_underway = NaiveDateTime.add(DateTime.to_naive(now), -24, :hour)
      end_underway = NaiveDateTime.add(DateTime.to_naive(now), 24, :hour)

      event_underway =
        event_fixture(%{
          title: "Multi-day Underway Event",
          begin_local: begin_underway,
          end_local: end_underway,
          registration_deadline_local: NaiveDateTime.add(begin_underway, -1, :day)
        })

      # Upcoming: starts in 2 days
      begin_upcoming = NaiveDateTime.add(DateTime.to_naive(now), 2, :day)

      event_upcoming =
        event_fixture(%{
          title: "Future Event",
          begin_local: begin_upcoming,
          registration_deadline_local: NaiveDateTime.add(begin_upcoming, -1, :day)
        })

      # Archived: ended 2 days ago
      begin_archived = NaiveDateTime.add(DateTime.to_naive(now), -5, :day)
      end_archived = NaiveDateTime.add(DateTime.to_naive(now), -2, :day)

      event_archived =
        event_fixture(%{
          title: "Past Multi-day Event",
          begin_local: begin_archived,
          end_local: end_archived,
          registration_deadline_local: NaiveDateTime.add(begin_archived, -1, :day)
        })

      # Register user for all
      for event <- [event_underway, event_upcoming, event_archived] do
        Events.create_event_attendee(
          event,
          user,
          %{
            "lang_ids" => [Enum.at(event.langs, 0).id]
          },
          :host
        )
      end

      {:ok, view, _html} = live(conn, ~p"/user/events")

      assert has_element?(view, "#underway-events")
      assert has_element?(view, "a", "Multi-day Underway Event")

      assert has_element?(view, "#upcoming-events")
      assert has_element?(view, "a", "Future Event")

      assert has_element?(view, "#archived-events")
      assert has_element?(view, "a", "Past Multi-day Event")
    end

    test "updates in real-time on new registration", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/user/events")
      assert html =~ "No registrations found"

      future_begin = NaiveDateTime.add(NaiveDateTime.local_now(), 2, :day)

      event =
        event_fixture(%{
          title: "New Registration",
          begin_local: future_begin,
          registration_deadline_local: NaiveDateTime.add(future_begin, -1, :day)
        })

      # Simulate registration
      {:ok, attendee} =
        Events.create_event_attendee(event, user, %{
          "lang_ids" => [Enum.at(event.langs, 0).id]
        })

      # Broadcast
      DevRoundWeb.Endpoint.broadcast("registrations", "created", {:created, event, attendee})

      assert render(view) =~ "New Registration"
    end

    test "renders team information for underway sessions", %{conn: conn, user: user} do
      tz = Application.get_env(:dev_round, :time_zone)
      {:ok, now} = DateTime.now(tz)

      # Underway event
      begin = NaiveDateTime.add(DateTime.to_naive(now), -1, :hour)

      event =
        event_fixture(%{
          title: "Team Display Event",
          begin_local: begin,
          end_local: NaiveDateTime.add(begin, 24, :hour),
          registration_deadline_local: NaiveDateTime.add(begin, -1, :day)
        })

      # bypass deadline check for testing team display
      %DevRound.Events.EventAttendee{}
      |> Ecto.Changeset.change(%{
        event_id: event.id,
        user_id: user.id,
        experience_level: 3,
        is_remote: false
      })
      |> DevRound.Repo.insert!()

      session = hd(event.sessions)
      # Mark session as team locked so teams are loaded
      session |> Ecto.Changeset.change(%{teams_locked: true}) |> DevRound.Repo.update!()

      lang = Enum.at(event.langs, 0)

      # Create team manually
      {:ok, team} =
        %DevRound.Hosting.Team{}
        |> Ecto.Changeset.change(%{
          name: "The Dream Team",
          slug: "dream-team",
          is_remote: false,
          session_id: session.id,
          lang_id: lang.id
        })
        |> DevRound.Repo.insert()

      # Add user to team
      %DevRound.Hosting.TeamMember{}
      |> Ecto.Changeset.change(%{
        team_id: team.id,
        user_id: user.id,
        experience_level: 3,
        is_remote: false
      })
      |> DevRound.Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/user/events")

      assert html =~ "The Dream Team"
    end

    test "expands multiple archived events", %{conn: conn, user: user} do
      tz = Application.get_env(:dev_round, :time_zone)
      {:ok, now} = DateTime.now(tz)

      # Archived events
      begin_archived = NaiveDateTime.add(DateTime.to_naive(now), -10, :day)
      end_archived = NaiveDateTime.add(DateTime.to_naive(now), -8, :day)

      archived_attrs = %{
        begin_local: begin_archived,
        end_local: end_archived,
        registration_deadline_local: NaiveDateTime.add(begin_archived, -1, :day)
      }

      event1 = event_fixture(Map.merge(archived_attrs, %{title: "Event 1"}))
      event2 = event_fixture(Map.merge(archived_attrs, %{title: "Event 2"}))

      for {event, index} <- Enum.with_index([event1, event2]) do
        Events.create_event_attendee(
          event,
          user,
          %{"lang_ids" => [Enum.at(event.langs, 0).id]},
          :host
        )

        # Mark sessions as team locked and give unique title
        for {session, s_index} <- Enum.with_index(event.sessions) do
          session
          |> Ecto.Changeset.change(%{
            teams_locked: true,
            title: "Archived Event #{index + 1} Session #{s_index + 1}"
          })
          |> DevRound.Repo.update!()
        end
      end

      {:ok, view, _html} = live(conn, ~p"/user/events")

      # Initially not expanded
      refute has_element?(view, "h2", "Archived Event 1 Session 1")
      refute has_element?(view, "h2", "Archived Event 1 Session 1")
      refute has_element?(view, "h2", "Archived Event 2 Session 1")

      # Expand event 1
      view |> render_click("toggle_expand", %{"id" => to_string(event1.id), "expanded" => false})
      assert has_element?(view, "h2", "Archived Event 1 Session 1")
      assert has_element?(view, "h2", "Archived Event 1 Session 1")
      refute has_element?(view, "h2", "Archived Event 2 Session 1")

      # Expand event 2
      view |> render_click("toggle_expand", %{"id" => to_string(event2.id), "expanded" => false})
      assert has_element?(view, "h2", "Archived Event 1 Session 1")
      assert has_element?(view, "h2", "Archived Event 1 Session 1")
      assert has_element?(view, "h2", "Archived Event 2 Session 1")
    end
  end
end
