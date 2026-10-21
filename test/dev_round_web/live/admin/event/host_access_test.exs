defmodule DevRoundWeb.Admin.Event.HostAccessTest do
  use DevRoundWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  alias DevRound.Events
  alias DevRound.Events.Event

  setup %{conn: conn} do
    host = user_fixture(%{full_name: "Host User"})
    other_host = user_fixture(%{full_name: "Other Host"})

    # Use minute-aligned times: the edit form uses `datetime-local` inputs
    # which drop seconds, so a second-aligned begin would make re-submitted
    # sessions appear to start before the event.
    begin_local =
      NaiveDateTime.local_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.add(1, :day)
      |> Map.replace!(:second, 0)

    lang = lang_fixture(%{name: "Hosted Lang"})
    other_lang = lang_fixture(%{name: "Other Lang"})

    event =
      event_fixture(%{
        host: host,
        title: "Hosted Event",
        begin_local: begin_local,
        put_langs: [lang]
      })

    other_event = event_fixture(%{host: other_host, title: "Other Event"})

    %{
      conn: conn,
      host: host,
      other_host: other_host,
      event: event,
      other_event: other_event,
      lang: lang,
      other_lang: other_lang
    }
  end

  describe "host access to admin events" do
    test "host can access the index and only sees their own events", %{
      conn: conn,
      host: host,
      event: event,
      other_event: other_event
    } do
      conn = log_in_user(conn, host)

      {:ok, view, _html} = live(conn, ~p"/admin/events")

      assert has_element?(view, "#row-item-#{event.id}")
      refute has_element?(view, "#row-item-#{other_event.id}")
    end

    test "host can access the edit action for their own event", %{
      conn: conn,
      host: host,
      event: event
    } do
      conn = log_in_user(conn, host)

      {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      assert has_element?(view, "#resource-form")
      assert has_element?(view, "input[name='change[location]']")
    end

    test "host cannot access the new action", %{conn: conn, host: host} do
      conn = log_in_user(conn, host)

      assert_raise Backpex.ForbiddenError, fn ->
        live(conn, ~p"/admin/events/new")
      end
    end

    test "host cannot access the show action", %{conn: conn, host: host, event: event} do
      conn = log_in_user(conn, host)

      assert_raise Backpex.ForbiddenError, fn ->
        live(conn, ~p"/admin/events/#{event.id}/show")
      end
    end

    test "host cannot edit another host's event", %{
      conn: conn,
      host: host,
      other_event: other_event
    } do
      conn = log_in_user(conn, host)

      assert_raise Backpex.NoResultsError, fn ->
        live(conn, ~p"/admin/events/#{other_event.id}/edit")
      end
    end

    test "host cannot duplicate an event through the item action", %{
      conn: conn,
      host: host,
      event: event
    } do
      # Ensure the action module is loaded so Backpex opens its confirmation modal
      # (its `has_confirm_modal?/1` check relies on the module being loaded).
      Code.ensure_loaded!(DevRoundWeb.Admin.ItemActions.DuplicateEventAction)

      conn = log_in_user(conn, host)

      {:ok, view, _html} = live(conn, ~p"/admin/events")

      view
      |> render_click("item-action", %{"action-key" => "duplicate", "item-id" => "#{event.id}"})

      # The confirm modal opens, but submitting must not create a copy.
      view
      |> form("#resource-form")
      |> render_submit(%{"change" => %{"title" => event.title <> " (copy)"}})

      refute DevRound.Repo.get_by(DevRound.Events.Event, title: event.title <> " (copy)")
    end

    test "host cannot access other admin resources", %{conn: conn, host: host} do
      conn = log_in_user(conn, host)

      assert_raise DevRoundWeb.PermissionError, fn ->
        live(conn, ~p"/admin/users")
      end

      assert_raise DevRoundWeb.PermissionError, fn ->
        live(conn, ~p"/admin/langs")
      end
    end

    test "user who hosts no event cannot access the admin events view", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert_raise DevRoundWeb.PermissionError, fn ->
        live(conn, ~p"/admin/events")
      end
    end
  end

  describe "host field restrictions" do
    test "protected fields are rendered read-only", %{
      conn: conn,
      host: host,
      event: event,
      lang: lang
    } do
      conn = log_in_user(conn, host)

      {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      assert has_element?(view, "input[name='change[title]'][disabled]")
      assert has_element?(view, "input[name='change[begin_local]'][disabled]")
      assert has_element?(view, "input[name='change[end_local]'][disabled]")
      assert has_element?(view, "input[name='change[registration_deadline_local]'][disabled]")
      assert has_element?(view, "input[name='change[location]'][disabled]")

      # Hosts are shown as a read-only table, without the editable delete controls.
      refute has_element?(view, "#event_hosts-checkbox-delete-0")
      assert view |> element("#resource-form") |> render() =~ host.full_name

      # Programming languages, published and remote participation are read-only too.
      refute has_element?(view, "#has-many-langs-checkbox-value-#{lang.id}")
      assert view |> element("#resource-form") |> render() =~ lang.name
      refute has_element?(view, "input[name='change[published]']")
      refute has_element?(view, "input[name='change[allow_remote_participation]']")

      # Video conference room fields are read-only as well.
      refute has_element?(view, "input[name='change[main_video_conference_room_url]']")
      refute has_element?(view, "input[name='change[team_video_conference_rooms_order][]']")
    end

    test "protected fields cannot be changed even when submitted", %{
      conn: conn,
      host: host,
      event: event,
      lang: lang,
      other_lang: other_lang
    } do
      conn = log_in_user(conn, host)

      event = DevRound.Events.get_event!(event.id)
      assert event.published
      assert event.allow_remote_participation
      assert Enum.map(event.langs, & &1.id) == [lang.id]

      {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      view
      |> form("#resource-form")
      |> render_submit(%{
        "save-type" => "save",
        "change" => %{
          "title" => "Hacked Title",
          "location" => "Remote Hall",
          "teaser" => "Changed teaser",
          "main_video_conference_room_url" => "https://evil.example.com/room",
          "langs" => [to_string(other_lang.id)],
          "published" => "false",
          "allow_remote_participation" => "false",
          "team_video_conference_rooms" => %{
            "0" => %{"url" => "https://evil.example.com/team"}
          },
          "team_video_conference_rooms_order" => ["0"]
        }
      })

      updated = DevRound.Events.get_event!(event.id)

      # Editable field did change.
      assert updated.teaser == "Changed teaser"

      # Protected fields did not change.
      assert updated.title == event.title
      assert updated.location == event.location
      assert updated.main_video_conference_room_url == event.main_video_conference_room_url
      assert updated.published
      assert updated.allow_remote_participation
      assert Enum.map(updated.langs, & &1.id) == [lang.id]
      assert updated.team_video_conference_rooms == []
    end

    test "admins can still create, delete and edit protected fields", %{
      conn: conn,
      event: event,
      other_lang: other_lang
    } do
      admin = user_fixture(%{role: :admin})

      {:ok, admin} =
        admin
        |> DevRound.Accounts.User.upsert_changeset(%{role: :admin})
        |> DevRound.Repo.update()

      conn = log_in_user(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      refute has_element?(view, "input[name='change[title]'][disabled]")
      assert has_element?(view, "#has-many-langs")
      assert has_element?(view, "input[name='change[published]']")
      assert has_element?(view, "input[name='change[allow_remote_participation]']")
      assert has_element?(view, "input[name='change[location]']")
      assert has_element?(view, "input[name='change[main_video_conference_room_url]']")
      assert has_element?(view, "input[name='change[team_video_conference_rooms_order][]']")

      view
      |> form("#resource-form")
      |> render_submit(%{
        "save-type" => "save",
        "change" => %{
          "title" => "Admin Renamed",
          "published" => "false",
          "location" => "Admin Location",
          "langs" => [to_string(other_lang.id)]
        }
      })

      updated = Event |> DevRound.Repo.get!(event.id) |> DevRound.Repo.preload(:langs)
      assert updated.title == "Admin Renamed"
      assert updated.location == "Admin Location"
      refute updated.published
      assert other_lang.id in Enum.map(updated.langs, & &1.id)
    end
  end

  describe "edit entry points" do
    test "event page exposes an edit button for hosts", %{conn: conn, host: host, event: event} do
      conn = log_in_user(conn, host)

      {:ok, view, _html} = live(conn, ~p"/events/#{event}")

      assert has_element?(view, "a[href='/admin/events/#{event.id}/edit']")
    end

    test "event page hides the edit button for non-hosts", %{conn: conn, event: event} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} = live(conn, ~p"/events/#{event}")

      refute has_element?(view, "a[href='/admin/events/#{event.id}/edit'].btn")
    end

    test "hosting screens expose the edit button", %{conn: conn, host: host, event: event} do
      conn = log_in_user(conn, host)

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby")
      assert has_element?(view, "a[href='/admin/events/#{event.id}/edit']")

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lecture")
      assert has_element?(view, "a[href='/admin/events/#{event.id}/edit']")
    end
  end

  describe "Events.user_is_host?/1" do
    test "returns true for hosts and false otherwise", %{host: host} do
      assert Events.user_is_host?(host)
      refute Events.user_is_host?(user_fixture())
    end
  end
end
