defmodule DevRoundWeb.Admin.Event.CreditedHostsAdminTest do
  use DevRoundWeb.ConnCase, async: false
  import DevRound.EventsFixtures
  import Phoenix.LiveViewTest

  test "renders credited toggle for hosts in admin", %{conn: conn} do
    admin = DevRound.AccountsFixtures.user_fixture(%{role: :admin})

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin}) |> DevRound.Repo.update()

    host1 = DevRound.AccountsFixtures.user_fixture()
    host2 = DevRound.AccountsFixtures.user_fixture()

    event =
      event_fixture(%{
        event_hosts: [
          %{user_id: host1.id, credited: true},
          %{user_id: host2.id, credited: true}
        ]
      })

    conn = log_in_user(conn, admin)

    {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

    assert has_element?(view, "#inline-crud-header-label-event_hosts-credited", "Credited")

    # Initially both hosts are credited
    event = DevRound.Repo.preload(event, :event_hosts, force: true)
    assert Enum.all?(event.event_hosts, & &1.credited)

    view
    |> form("#resource-form")
    |> render_submit(%{
      "save-type" => "save",
      "change" => %{
        "event_hosts" => %{
          "0" => %{
            "user_id" => "#{host1.id}",
            "credited" => "true"
          },
          "1" => %{
            "user_id" => "#{host2.id}",
            "credited" => "false"
          }
        }
      }
    })

    # Reload event and verify host2 is now uncredited while host1 is credited
    event = DevRound.Repo.preload(event, :event_hosts, force: true)

    assert Enum.any?(event.event_hosts, fn eh ->
             eh.user_id == host2.id and eh.credited == false
           end)

    assert Enum.any?(event.event_hosts, fn eh ->
             eh.user_id == host1.id and eh.credited == true
           end)
  end

  test "shows error when trying to save event with no credited hosts", %{conn: conn} do
    admin = DevRound.AccountsFixtures.user_fixture(%{role: :admin})

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin}) |> DevRound.Repo.update()

    host = DevRound.AccountsFixtures.user_fixture()
    event = event_fixture(%{event_hosts: [%{user_id: host.id, credited: true}]})
    conn = log_in_user(conn, admin)

    {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

    html =
      view
      |> form("#resource-form")
      |> render_submit(%{
        "save-type" => "save",
        "change" => %{
          "event_hosts" => %{
            "0" => %{
              "user_id" => "#{host.id}",
              "credited" => "false"
            }
          }
        }
      })

    assert html =~ "At least one credited host is required."
  end
end
