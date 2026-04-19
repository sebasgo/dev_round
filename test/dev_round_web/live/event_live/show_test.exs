defmodule DevRoundWeb.EventLive.ShowTest do
  use DevRoundWeb.ConnCase
  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    lang = lang_fixture()

    # Create event in the future relative to now
    now = NaiveDateTime.truncate(NaiveDateTime.local_now(), :second)
    begin_local = NaiveDateTime.add(now, 3, :day)
    deadline_local = NaiveDateTime.add(begin_local, -1, :day)

    event =
      event_fixture(%{
        put_langs: [lang],
        begin_local: begin_local,
        registration_deadline_local: deadline_local
      })

    # Update session to match new begin
    event = DevRound.Repo.preload(event, [:sessions])

    for session <- event.sessions do
      DevRound.Repo.update!(
        DevRound.Events.EventSession.changeset(session, %{
          begin_local: begin_local,
          end_local: NaiveDateTime.add(begin_local, 1, :hour)
        })
      )
    end

    conn = log_in_user(conn, user)
    %{conn: conn, event: DevRound.Events.get_event!(event.id), user: user, lang: lang}
  end

  describe "Event Show" do
    test "renders event details correctly", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/events/#{event}")
      header_html = element(view, "main header") |> render()
      assert header_html =~ event.title
      assert Enum.all?(event.hosts, fn host -> header_html =~ host.full_name end)
    end

    test "redirects if user is not logged in", %{event: event} do
      conn = build_conn()
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/events/#{event}")
    end

    test "shows hosting control to hosts only", %{conn: conn, event: event, user: user} do
      {:ok, view, _html} = live(conn, ~p"/events/#{event}")
      refute has_element?(view, ".btn", "Host")

      # Add user as host
      DevRound.Repo.insert!(%DevRound.Events.EventHost{event_id: event.id, user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/events/#{event}")
      assert has_element?(view, ".btn", "Host")
    end

    test "registration, update, and cancellation for single lang event", %{
      conn: conn,
      event: event,
      user: user
    } do
      # Ensure event is open
      assert DevRound.Events.event_open_for_registration?(event)

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/registration/new")

      assert has_element?(view, "#event-form")

      assert view
             |> form("#event-form", event_attendee: %{is_remote: "false"})
             |> render_submit() =~ "Registration successful."

      # Verify attendee shows up
      {:ok, view, html} = live(conn, ~p"/events/#{event}")

      assert html =~ "Manage Registration"
      assert has_element?(view, ".badge-success", "You have registered")
      assert has_element?(view, ".attendees", user.full_name)

      # Update registration

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/registration/edit")

      assert view
             |> form("#event-form", event_attendee: %{is_remote: "true"})
             |> render_submit() =~ "Registration information updated."

      # Cancel
      {:ok, view, _html} = live(conn, ~p"/events/#{event}/registration/edit")

      assert render_click(element(view, "button", "Cancel Registration")) =~
               "Registration canceled."

      {:ok, view, _html} = live(conn, ~p"/events/#{event}")
      refute has_element?(view, ".attendees", user.full_name)
    end

    test "registration for multi-language event", %{conn: conn, user: user} do
      lang1 = lang_fixture(name: "Elixir")
      lang2 = lang_fixture(name: "Python")

      now = NaiveDateTime.truncate(NaiveDateTime.local_now(), :second)

      event =
        event_fixture(%{
          put_langs: [lang1, lang2],
          begin_local: NaiveDateTime.add(now, 3, :day),
          registration_deadline_local: NaiveDateTime.add(now, 2, :day)
        })

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/registration/new")

      params = %{
        "is_remote" => "true",
        "lang_ids" => [Integer.to_string(lang1.id), Integer.to_string(lang2.id)]
      }

      assert view
             |> form("#event-form", event_attendee: params)
             |> render_submit() =~ "Registration successful."

      # Verify attendee shows up with languages
      {:ok, view, _html} = live(conn, ~p"/events/#{event}")
      assert has_element?(view, ".attendees", user.full_name)
      assert has_element?(view, ".attendees", "Elixir")
      assert has_element?(view, ".attendees", "Python")
    end

    test "registration deadline enforcement", %{conn: conn} do
      past_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), -1, :day)
      event = event_fixture(%{registration_deadline_local: past_deadline})

      {:ok, _view, html} = live(conn, ~p"/events/#{event}")
      refute html =~ "Register"

      assert {:error,
              {:live_redirect, %{flash: %{"error" => "Registration for this event is closed."}}}} =
               live(conn, ~p"/events/#{event}/registration/new")
    end
  end
end
