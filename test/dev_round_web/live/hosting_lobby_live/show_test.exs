defmodule DevRoundWeb.HostingLobbyLive.ShowTest do
  use DevRoundWeb.ConnCase
  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  defp register_attendee(event, name, is_remote, langs, checked) do
    user =
      user_fixture(%{
        name: name,
        full_name: name,
        email: "#{String.replace(name, " ", "")}@example.com",
        experience_level: 5
      })

    {:ok, attendee} =
      DevRound.Events.create_event_attendee(event, user, %{
        "is_remote" => is_remote,
        "lang_ids" => Enum.map(langs, & &1.id)
      })

    {:ok, updated} = DevRound.Hosting.update_event_attendee_checked(attendee, checked)
    updated
  end

  setup %{conn: conn} do
    user = user_fixture()
    lang = lang_fixture()

    # Set registration deadline to future
    future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)

    event =
      event_fixture(%{
        put_langs: [lang],
        registration_deadline_local: future_deadline
      })

    # Add user as host
    Ecto.Changeset.change(event)
    |> Ecto.Changeset.put_assoc(:event_hosts, [%DevRound.Events.EventHost{user_id: user.id}])
    |> DevRound.Repo.update!()

    conn = log_in_user(conn, user)

    %{conn: conn, event: event, host: user, lang: lang}
  end

  describe "Hosting Lobby Show" do
    test "loads correctly and lists attendees", %{conn: conn, event: event, lang: lang} do
      register_attendee(event, "User 1", false, [lang], false)

      {:ok, _view, html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      assert html =~ "User 1"
    end

    test "denies access to non-host users", %{conn: conn, event: event} do
      conn = log_in_user(conn, user_fixture())

      assert_raise DevRoundWeb.PermissionError, fn ->
        live(conn, ~p"/events/#{event}/hosting/lobby")
      end
    end

    test "allows checking in and checking out attendees", %{conn: conn, event: event, lang: lang} do
      _attendee = register_attendee(event, "User 1", false, [lang], false)

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      assert view |> element("button", "Check in") |> render()
      # In the template, "Check out" is disabled initially if not checked in.
      assert view |> element("button", "Check out") |> render() =~ "disabled"

      # Check in
      view |> element("button", "Check in") |> render_click()
      refute view |> element("button", "Check out") |> render() =~ "disabled"

      # Check out
      view |> element("button", "Check out") |> render_click()

      assert view |> element("button", "Check in") |> render()
    end
  end
end
