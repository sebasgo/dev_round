defmodule DevRoundWeb.HostingSessionLive.ShowTest do
  use DevRoundWeb.ConnCase
  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures
  import DevRound.HostingFixtures

  defp team_fixture(session, lang, attrs) do
    %DevRound.Hosting.Team{}
    |> Ecto.Changeset.change(%{
      name: "some team #{System.unique_integer()}",
      slug: "some-team-#{System.unique_integer()}",
      session_id: session.id,
      lang_id: lang.id
    })
    |> Ecto.Changeset.change(attrs)
    |> DevRound.Repo.insert!()
  end

  defp register_attendee(event, name, is_remote, langs, checked \\ true, experience \\ nil) do
    experience = experience || Enum.random(0..9)

    user =
      user_fixture(%{
        name: name,
        full_name: name,
        email: "#{String.replace(name, " ", "")}@example.com",
        experience_level: experience
      })

    {:ok, attendee} =
      DevRound.Events.create_event_attendee(event, user, %{
        "is_remote" => is_remote,
        "lang_ids" => Enum.map(langs, & &1.id)
      })

    {:ok, _updated} = DevRound.Hosting.update_event_attendee_checked(attendee, checked)
  end

  setup %{conn: conn} do
    user = user_fixture()
    lang = lang_fixture()

    future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)

    event =
      event_fixture(%{
        put_langs: [lang],
        main_video_conference_room_url: "https://lecture.com",
        registration_deadline_local: future_deadline
      })

    # Add user as host
    Ecto.Changeset.change(event)
    |> Ecto.Changeset.put_assoc(:event_hosts, [%DevRound.Events.EventHost{user_id: user.id}])
    |> DevRound.Repo.update!()

    # Manually insert video conference rooms
    %DevRound.Events.TeamVideoConferenceRoom{}
    |> Ecto.Changeset.change(%{url: "https://room1.com", event_id: event.id})
    |> DevRound.Repo.insert!()

    session = hd(event.sessions)
    conn = log_in_user(conn, user)

    %{conn: conn, event: event, session: session, host: user, lang: lang}
  end

  describe "Hosting Session Show" do
    test "loads correctly with video conference rooms preloaded", %{
      conn: conn,
      event: event,
      session: session
    } do
      assert {:ok, _view, _html} = live(conn, ~p"/events/#{event}/hosting/session/#{session}")
    end

    test "denies access to non-host users", %{conn: conn, event: event, session: session} do
      conn = log_in_user(conn, user_fixture())

      assert_raise DevRoundWeb.PermissionError, fn ->
        live(conn, ~p"/events/#{event}/hosting/session/#{session}")
      end
    end

    test "can build teams and manage session lifecycle", %{
      conn: conn,
      event: event,
      session: session,
      lang: lang
    } do
      team_name_fixture()

      # Register 2 checked-in attendees to satisfy team generation constraints
      register_attendee(event, "User 1", false, [lang])
      register_attendee(event, "User 2", false, [lang])

      {:ok, view, html} = live(conn, ~p"/events/#{event}/hosting/session/#{session}")

      assert html =~ "Build Teams"
      refute view |> element("button", "Build Teams") |> render() =~ "disabled"

      # Build Teams
      view |> element("button", "Build Teams") |> render_click()

      html = render(view)
      assert html =~ "Teams generated. You may start the session now."

      # Start Session
      view |> element("button", "Start Session") |> render_click()

      html = render(view)
      assert html =~ "started."
      # Countdown should be visible
      assert html =~ "Time Remaining"

      # Stop/Return to Lecture
      view |> element("button", "Return to Lecture") |> render_click()
      assert_redirected(view, ~p"/events/#{event}/hosting/lecture")

      # Re-visit the session liveview
      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/session/#{session}")

      # Now it should be stopped natively but teams are still assigned.
      # Reset Session
      view |> element("button", "Reset Session") |> render_click()

      html = render(view)
      assert html =~ "Session reset. You may build new teams now."
      assert html =~ "The teams for this session have not been assigned yet."
    end
  end

  describe "PubSub events" do
    test "handles event update (title change)", %{conn: conn, event: event, session: session} do
      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/session/#{session}")

      # Broadcast event update with new title
      # Changing event title (the event itself)
      new_event_title = "New Event Title"

      updated_event =
        Ecto.Changeset.change(event, %{title: new_event_title})
        |> DevRound.Repo.update!(force: true)

      # The view handler updates itself
      send(view.pid, {"updated", updated_event})
      assert render(view) =~ new_event_title
    end

    test "handles team_built event", %{conn: conn, event: event, session: session, lang: lang} do
      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/session/#{session}")
      refute render(view) =~ "Team Bravo"

      _team = team_fixture(session, lang, %{name: "Team Bravo"})

      send(view.pid, %{
        topic: "event_sessions",
        event: "teams_built",
        payload: %{event_session_id: session.id}
      })

      assert render(view) =~ "Team Bravo"
    end
  end
end
