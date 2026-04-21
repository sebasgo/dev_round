defmodule DevRoundWeb.EventLive.IndexTest do
  use DevRoundWeb.ConnCase
  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    lang = lang_fixture()
    now = NaiveDateTime.truncate(NaiveDateTime.local_now(), :second)

    # Current published event
    current_event =
      event_fixture(%{
        title: "Current Event",
        put_langs: [lang],
        begin_local: NaiveDateTime.shift(now, day: 2),
        end_local: NaiveDateTime.shift(now, day: 2, hour: 2)
      })

    # Archived published event
    archived_event =
      event_fixture(%{
        title: "Archived Event",
        put_langs: [lang],
        begin_local: NaiveDateTime.shift(now, day: -5),
        end_local: NaiveDateTime.shift(now, day: -5, hour: 2),
        registration_deadline_local: NaiveDateTime.shift(now, day: -6)
      })

    # Unpublished event (should never appear)
    unpublished_event =
      event_fixture(%{
        title: "Hidden Event",
        put_langs: [lang],
        published: false,
        begin_local: NaiveDateTime.shift(now, day: 3)
      })

    # Matching published event for search
    matching_event =
      event_fixture(%{
        title: "Elixir Summit",
        put_langs: [lang]
      })

    # Non‑matching published event for search
    other_event =
      event_fixture(%{
        title: "Phoenix Conference",
        put_langs: [lang]
      })

    conn = log_in_user(conn, user)

    %{
      conn: conn,
      current_event: current_event,
      archived_event: archived_event,
      unpublished_event: unpublished_event,
      matching_event: matching_event,
      other_event: other_event,
      user: user,
      lang: lang
    }
  end

  test "redirects if user is not logged in", %{} do
    conn = build_conn()
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/events")
  end

  test "search query in URL shows only matching published results", %{
    conn: conn,
    matching_event: matching_event,
    other_event: other_event,
    unpublished_event: unpublished_event
  } do
    {:ok, _view, html} = live(conn, ~p"/events?query=Elixir")
    assert html =~ "Search Results"
    assert html =~ matching_event.title
    refute html =~ other_event.title
    refute html =~ unpublished_event.title
  end

  test "search form changes update URL and display only matching published results", %{
    conn: conn,
    matching_event: matching_event,
    other_event: other_event,
    unpublished_event: unpublished_event
  } do
    {:ok, view, _html} = live(conn, ~p"/events")

    view
    |> form("#search-from", %{"query" => "Elixir"})
    |> render_change()

    assert_patch(view, "/events?query=Elixir")
    html = render(view)
    assert html =~ matching_event.title
    refute html =~ other_event.title
    refute html =~ unpublished_event.title
  end

  test "page shows current and archived events, excludes unpublished", %{
    conn: conn,
    current_event: current_event,
    archived_event: archived_event,
    unpublished_event: unpublished_event
  } do
    {:ok, _view, html} = live(conn, ~p"/events")
    assert html =~ current_event.title
    assert html =~ archived_event.title
    refute html =~ unpublished_event.title
  end
end
