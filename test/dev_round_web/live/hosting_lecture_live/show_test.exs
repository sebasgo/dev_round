defmodule DevRoundWeb.HostingLectureLive.ShowTest do
  use DevRoundWeb.ConnCase
  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    event = event_fixture(%{live: false})

    # Add user as host
    Ecto.Changeset.change(event)
    |> Ecto.Changeset.put_assoc(:event_hosts, [%DevRound.Events.EventHost{user_id: user.id}])
    |> DevRound.Repo.update!()

    conn = log_in_user(conn, user)

    %{conn: conn, event: event, host: user}
  end

  describe "Hosting Lecture Show" do
    test "loads correctly", %{conn: conn, event: event} do
      assert {:ok, _view, html} = live(conn, ~p"/events/#{event}/hosting/lecture")
      assert html =~ "Hosting Lecture"
    end

    test "denies access to non-host users", %{conn: conn, event: event} do
      conn = log_in_user(conn, user_fixture())

      assert_raise DevRoundWeb.PermissionError, fn ->
        live(conn, ~p"/events/#{event}/hosting/lecture")
      end
    end

    test "can start and stop presentation", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lecture")

      # Start Presentation
      view |> element("button", "Start Presentation") |> render_click(%{live: true})
      assert render(view) =~ "Presentation started."
      assert view |> element("button", "Start Presentation") |> render() =~ "disabled"

      # Stop Presentation
      view |> element("button", "Stop Presentation") |> render_click(%{live: false})
      assert render(view) =~ "Presentation stopped."
    end
  end
end
