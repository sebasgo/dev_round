defmodule DevRoundWeb.Admin.EventAttendeesLiveTest do
  use DevRoundWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import DevRound.AccountsFixtures
  import DevRound.EventsFixtures

  alias DevRound.Events
  alias DevRound.Events.EventAttendee

  defp admin_fixture do
    admin = user_fixture()

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin})
      |> DevRound.Repo.update()

    admin
  end

  defp attendee_fixture(event) do
    user = user_fixture(%{experience_level: 3})

    {:ok, attendee} =
      Events.create_event_attendee(event, user, %{
        "is_remote" => true,
        "lang_ids" => Enum.map(event.langs, & &1.id)
      })

    {attendee, user}
  end

  defp backdate_attendee(%EventAttendee{} = attendee, datetime) do
    {1, _} =
      DevRound.Repo.update_all(
        from(a in EventAttendee, where: a.id == ^attendee.id),
        set: [inserted_at: datetime]
      )

    :ok
  end

  test "renders the event attendees index", %{conn: conn} do
    admin = admin_fixture()
    deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
    event = event_fixture(%{registration_deadline_local: deadline})
    {attendee, user} = attendee_fixture(event)

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/event_attendees")

    assert has_element?(view, "#row-item-#{attendee.id}")
    assert has_element?(view, "#row-item-#{attendee.id}", user.full_name)
    assert has_element?(view, "#row-item-#{attendee.id}", event.title)
  end

  test "orders attendees by most recent registration first", %{conn: conn} do
    admin = admin_fixture()
    deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
    event = event_fixture(%{registration_deadline_local: deadline})

    {older, _older_user} = attendee_fixture(event)
    :ok = backdate_attendee(older, DateTime.utc_now() |> DateTime.add(-3600, :second))
    {newer, _newer_user} = attendee_fixture(event)

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/event_attendees")

    ids =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("tr[id^='row-item-']")
      |> LazyHTML.attributes()
      |> Enum.map(fn attrs -> attrs |> List.keyfind("id", 0) |> elem(1) end)

    assert ids == ["row-item-#{newer.id}", "row-item-#{older.id}"]
  end
end
