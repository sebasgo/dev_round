defmodule DevRoundWeb.Admin.Event.DuplicateItemActionLiveTest do
  use DevRoundWeb.ConnCase, async: false
  import DevRound.EventsFixtures
  import Phoenix.LiveViewTest

  test "duplicates event from index", %{conn: conn} do
    # Create an admin user required for authentication
    admin = DevRound.AccountsFixtures.user_fixture(%{role: :admin})

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin}) |> DevRound.Repo.update()

    # Create an initial event
    event = event_fixture()

    conn = log_in_user(conn, admin)
    {:ok, view, _html} = live(conn, ~p"/admin/events")

    # Trigger the duplicate action (Backpex item action)
    view
    |> render_click("item-action", %{"action-key" => "duplicate", "item-id" => "#{event.id}"})

    # Find the modal form
    view
    |> form("#resource-form")
    |> render_submit(%{"change" => %{"title" => event.title <> " (copy)"}})

    # Verify a new event was created
    new_event = DevRound.Repo.get_by(DevRound.Events.Event, title: event.title <> " (copy)")
    assert new_event
    new_event = DevRound.Repo.preload(new_event, :event_hosts)
    assert Enum.map(new_event.event_hosts, & &1.credited) == [true]
  end

  test "duplicates event preserving uncredited hosts", %{conn: conn} do
    admin = DevRound.AccountsFixtures.user_fixture(%{role: :admin})

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin}) |> DevRound.Repo.update()

    host1 = DevRound.AccountsFixtures.user_fixture()
    host2 = DevRound.AccountsFixtures.user_fixture()

    event =
      event_fixture(%{
        event_hosts: [
          %{user_id: host1.id, credited: true},
          %{user_id: host2.id, credited: false}
        ]
      })

    conn = log_in_user(conn, admin)
    {:ok, view, _html} = live(conn, ~p"/admin/events")

    view
    |> render_click("item-action", %{"action-key" => "duplicate", "item-id" => "#{event.id}"})

    view
    |> form("#resource-form")
    |> render_submit(%{"change" => %{"title" => event.title <> " (copy)"}})

    new_event = DevRound.Repo.get_by(DevRound.Events.Event, title: event.title <> " (copy)")
    assert new_event
    new_event = DevRound.Repo.preload(new_event, [:event_hosts, :credited_hosts, :hosts])
    assert length(new_event.hosts) == 2
    assert length(new_event.credited_hosts) == 1

    assert Enum.any?(new_event.event_hosts, fn eh ->
             eh.user_id == host2.id and eh.credited == false
           end)
  end

  test "duplicates event from index with slides", %{conn: conn} do
    # Create an admin user required for authentication
    admin = DevRound.AccountsFixtures.user_fixture(%{role: :admin})

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin}) |> DevRound.Repo.update()

    # Create a source dummy slide file
    source_filename = "test-source-slides.pdf"
    slides_dir = Path.join([:code.priv_dir(:dev_round), DevRound.Events.event_slides_dir()])
    File.mkdir_p!(slides_dir)
    src_path = Path.join(slides_dir, source_filename)
    File.write!(src_path, "PDF mock content")

    # Create an initial event pointing to the slide file
    event = event_fixture(%{slides_filename: source_filename})

    conn = log_in_user(conn, admin)
    {:ok, view, _html} = live(conn, ~p"/admin/events")

    # Trigger the duplicate action (Backpex item action)
    view
    |> render_click("item-action", %{"action-key" => "duplicate", "item-id" => "#{event.id}"})

    # Find the modal form
    view
    |> form("#resource-form")
    |> render_submit(%{"change" => %{"title" => event.title <> " (copy)"}})

    # Verify a new event was created
    new_event = DevRound.Repo.get_by(DevRound.Events.Event, title: event.title <> " (copy)")
    assert new_event

    # Verify slides_filename has been changed to a new uuid, not copying the exact string
    assert new_event.slides_filename != nil
    assert new_event.slides_filename != event.slides_filename
    assert Path.extname(new_event.slides_filename) == ".pdf"

    # Verify the physical file is duplicated
    dest_path = Path.join(slides_dir, new_event.slides_filename)
    assert File.exists?(dest_path)
    assert File.read!(dest_path) == "PDF mock content"

    # Cleanup the created mock files
    File.rm!(src_path)
    File.rm!(dest_path)
  end
end
