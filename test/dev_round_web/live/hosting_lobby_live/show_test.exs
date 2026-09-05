defmodule DevRoundWeb.HostingLobbyLive.ShowTest do
  use DevRoundWeb.ConnCase
  import Phoenix.LiveViewTest
  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  defp register_attendee(event, name, is_remote, langs, checked, opts \\ []) do
    user =
      user_fixture(%{
        name: name,
        full_name: Keyword.get(opts, :full_name, name),
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

    # Set registration deadline and begin in the future by default
    future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
    future_begin = NaiveDateTime.add(NaiveDateTime.local_now(), 24, :hour)
    future_end = NaiveDateTime.add(future_begin, 2, :hour)

    event =
      event_fixture(%{
        put_langs: [lang],
        begin_local: future_begin,
        end_local: future_end,
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

    test "renders filter box and search order dropdown above attendee table", %{
      conn: conn,
      event: event
    } do
      {:ok, view, html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      assert has_element?(view, "form#attendees-filter-form")
      assert has_element?(view, "#attendees-filter-form input[type=search]")
      assert has_element?(view, "#attendees-filter-form select")
      assert has_element?(view, "#attendees-filter-form label", "Sort by")
      assert html =~ "Sort by"
      assert html =~ "Registration date"
      assert html =~ "Remote attendance / Name"
    end

    test "defaults to registration order when event has not started yet", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      # Register in order: Charlie, Alice, Bob
      register_attendee(event, "Charlie", false, [lang], false, full_name: "Charlie Davis")
      register_attendee(event, "Alice", false, [lang], false, full_name: "Alice Smith")
      register_attendee(event, "Bob", false, [lang], false, full_name: "Bob Jones")

      {:ok, view, html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      # Selected option in dropdown should be registration
      assert has_element?(
               view,
               "#attendees-filter-form select option[value='registration'][selected]"
             )

      # Order in HTML should reflect insertion order: Charlie -> Alice -> Bob
      charlie_pos = :binary.match(html, "Charlie Davis") |> elem(0)
      alice_pos = :binary.match(html, "Alice Smith") |> elem(0)
      bob_pos = :binary.match(html, "Bob Jones") |> elem(0)

      assert charlie_pos < alice_pos
      assert alice_pos < bob_pos
    end

    test "defaults to name and remote attendance order when event has already started", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      # Register attendees first while registration is open
      # In-person Zoe, In-person Aaron, Remote Bob
      register_attendee(event, "Zoe", false, [lang], false, full_name: "Zoe Brown")
      register_attendee(event, "Aaron", false, [lang], false, full_name: "Aaron Adams")
      register_attendee(event, "Bob", true, [lang], false, full_name: "Bob Clark")

      # Shift event begin date to the past
      past_begin = DateTime.utc_now(:second) |> DateTime.add(-2, :hour)
      past_end = DateTime.add(past_begin, 4, :hour)

      event
      |> Ecto.Changeset.change(%{
        begin: past_begin,
        end: past_end,
        begin_local: DateTime.to_naive(past_begin),
        end_local: DateTime.to_naive(past_end)
      })
      |> DevRound.Repo.update!()

      {:ok, view, html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      # Selected option in dropdown should be is_remote_and_full_name
      assert has_element?(
               view,
               "#attendees-filter-form select option[value='is_remote_and_full_name'][selected]"
             )

      # In-person (false) comes before Remote (true), and names are sorted A-Z:
      # Aaron Adams (in-person) -> Zoe Brown (in-person) -> Bob Clark (remote)
      aaron_pos = :binary.match(html, "Aaron Adams") |> elem(0)
      zoe_pos = :binary.match(html, "Zoe Brown") |> elem(0)
      bob_pos = :binary.match(html, "Bob Clark") |> elem(0)

      assert aaron_pos < zoe_pos
      assert zoe_pos < bob_pos
    end

    test "filters attendee list by single word substring of fullname", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "Alice", false, [lang], false, full_name: "Alice Wonderland")
      register_attendee(event, "Bob", false, [lang], false, full_name: "Bob Builder")

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      # Filter by "wonder"
      html =
        view
        |> element("#attendees-filter-form")
        |> render_change(%{"filter" => "wonder", "order" => "registration"})

      assert html =~ "Alice Wonderland"
      refute html =~ "Bob Builder"
      assert_patch(view, ~p"/events/#{event}/hosting/lobby?filter=wonder&order=registration")
    end

    test "filters attendee list by multiple words substring search to narrow down", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "John1", false, [lang], false, full_name: "John Doe")
      register_attendee(event, "John2", false, [lang], false, full_name: "John Smith")
      register_attendee(event, "Jane1", false, [lang], false, full_name: "Jane Doe")

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      # "John" matches both John Doe and John Smith
      html =
        view
        |> element("#attendees-filter-form")
        |> render_change(%{"filter" => "John", "order" => "registration"})

      assert html =~ "John Doe"
      assert html =~ "John Smith"
      refute html =~ "Jane Doe"

      # "John Doe" matches only John Doe
      html =
        view
        |> element("#attendees-filter-form")
        |> render_change(%{"filter" => "John Doe", "order" => "registration"})

      assert html =~ "John Doe"
      refute html =~ "John Smith"
      refute html =~ "Jane Doe"

      # "Doe John" (reversed words) also matches John Doe
      html =
        view
        |> element("#attendees-filter-form")
        |> render_change(%{"filter" => "Doe John", "order" => "registration"})

      assert html =~ "John Doe"
      refute html =~ "John Smith"
      refute html =~ "Jane Doe"
    end

    test "switching sort order dropdown changes attendee ordering immediately and updates URL", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      # Registered: Zoe (in-person), Aaron (in-person)
      register_attendee(event, "Zoe", false, [lang], false, full_name: "Zoe Brown")
      register_attendee(event, "Aaron", false, [lang], false, full_name: "Aaron Adams")

      {:ok, view, html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      # By default (event not started): registration order (Zoe before Aaron)
      zoe_pos = :binary.match(html, "Zoe Brown") |> elem(0)
      aaron_pos = :binary.match(html, "Aaron Adams") |> elem(0)
      assert zoe_pos < aaron_pos

      # Switch to name and remote attendance
      html =
        view
        |> element("#attendees-filter-form")
        |> render_change(%{"filter" => "", "order" => "is_remote_and_full_name"})

      assert_patch(view, ~p"/events/#{event}/hosting/lobby?order=is_remote_and_full_name")

      # Now Aaron before Zoe
      zoe_pos = :binary.match(html, "Zoe Brown") |> elem(0)
      aaron_pos = :binary.match(html, "Aaron Adams") |> elem(0)
      assert aaron_pos < zoe_pos
    end

    test "loads filtered and sorted list directly from query string", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "Zoe", false, [lang], false, full_name: "Zoe Brown")
      register_attendee(event, "Aaron", false, [lang], false, full_name: "Aaron Adams")
      register_attendee(event, "Bob", false, [lang], false, full_name: "Bob Jones")

      {:ok, view, html} =
        live(conn, ~p"/events/#{event}/hosting/lobby?filter=a&order=is_remote_and_full_name")

      # Form inputs should have query string values
      assert has_element?(view, "#attendees-filter-form input[value='a']")

      assert has_element?(
               view,
               "#attendees-filter-form select option[value='is_remote_and_full_name'][selected]"
             )

      # "a" matches "Aaron Adams" (contains 'a') and filters out "Zoe Brown" and "Bob Jones"
      assert html =~ "Aaron Adams"
      refute html =~ "Zoe Brown"
      refute html =~ "Bob Jones"
    end

    test "checkin and checkout preserve active filter and ordering", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "Alice", false, [lang], false, full_name: "Alice Smith")
      register_attendee(event, "Bob", false, [lang], false, full_name: "Bob Jones")

      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}/hosting/lobby?filter=Alice&order=registration")

      # Check in Alice
      html = view |> element("button", "Check in") |> render_click()

      # Alice is still visible and checked in
      assert html =~ "Alice Smith"
      refute html =~ "Bob Jones"
      refute view |> element("button", "Check out") |> render() =~ "disabled"

      # Check out Alice
      html = view |> element("button", "Check out") |> render_click()

      assert html =~ "Alice Smith"
      refute html =~ "Bob Jones"
      assert view |> element("button", "Check in") |> render()
    end

    test "renders toolbar with Add participant button", %{conn: conn, event: event} do
      {:ok, view, html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      assert has_element?(view, "a.btn-primary", "Add participant")
      assert html =~ "Add participant"
    end

    test "clicking Add participant opens modal with unregistered participants", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "RegisteredUser", false, [lang], false,
        full_name: "Registered Alice"
      )

      unregistered_user = user_fixture(%{name: "unregistered", full_name: "Unregistered Bob"})

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby")

      # Click Add participant button
      view |> element("a", "Add participant") |> render_click()

      assert_patch(view, ~p"/events/#{event}/hosting/lobby/registration/new?order=registration")
      assert has_element?(view, "#event-modal")
      assert has_element?(view, "#event-modal", "Add participant")

      # Unregistered user is in select, registered user is not
      assert has_element?(
               view,
               "#event-form select option[value='#{unregistered_user.id}']",
               "Unregistered Bob"
             )

      refute has_element?(view, "#event-form select option", "Registered Alice")
    end

    test "submitting without participant selection shows validation error", %{
      conn: conn,
      event: event
    } do
      _unregistered_user = user_fixture(%{name: "unregistered", full_name: "Unregistered Bob"})

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby/registration/new")

      assert view
             |> form("#event-form", event_attendee: %{user_id: "", is_remote: "false"})
             |> render_submit() =~ "Please select a participant."
    end

    test "adds participant successfully with confirmation flash and email", %{
      conn: conn,
      event: event
    } do
      import Swoosh.TestAssertions

      user =
        user_fixture(%{
          name: "newbie",
          full_name: "Newbie Developer",
          email: "newbie@example.com",
          experience_level: 3
        })

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby/registration/new")

      # Validate event updates experience level to user default
      html =
        view
        |> form("#event-form", event_attendee: %{user_id: to_string(user.id)})
        |> render_change()

      # Experience level 3 radio button should be selected
      assert html =~ ~s(value="3" checked)

      # Submit form with custom experience level and remote attendance
      submit_result =
        view
        |> form("#event-form",
          event_attendee: %{
            user_id: to_string(user.id),
            experience_level: "8",
            is_remote: "true"
          }
        )
        |> render_submit()

      assert submit_result =~ "Registration successful. Confirmation sent to Newbie Developer."

      # Modal is closed and participant is visible in lobby
      refute has_element?(view, "#event-modal")
      assert has_element?(view, "#attendees", "Newbie Developer")

      # Email was sent to the participant
      assert_email_sent(to: {"Newbie Developer", "newbie@example.com"})

      # Opening the modal again does not include the newly registered user
      view |> element("a", "Add participant") |> render_click()
      refute has_element?(view, "#event-form select option", "Newbie Developer")
    end

    test "hides remote option and forces local when remote participation is disabled", %{
      conn: conn,
      event: event
    } do
      {:ok, event} = DevRound.Events.update_event(event, %{allow_remote_participation: false})

      user =
        user_fixture(%{
          name: "inperson",
          full_name: "In Person User",
          email: "inperson@example.com",
          experience_level: 3
        })

      {:ok, view, _html} = live(conn, ~p"/events/#{event}/hosting/lobby/registration/new")

      refute has_element?(view, "#event-form", "Attend remotely")
      assert has_element?(view, "#event-form", "Remote participation is not available")

      submit_result =
        view
        |> form("#event-form",
          event_attendee: %{user_id: to_string(user.id), experience_level: "3"}
        )
        |> render_submit()

      assert submit_result =~ "Registration successful. Confirmation sent to In Person User."

      attendee =
        DevRound.Repo.get_by!(
          DevRound.Events.EventAttendee,
          event_id: event.id,
          user_id: user.id
        )

      assert attendee.is_remote == false
    end

    test "host can cancel participant registration from the lobby", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "Alice", false, [lang], false, full_name: "Alice Smith")

      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}/hosting/lobby")

      assert has_element?(view, "#attendees", "Alice Smith")

      # Click edit button link for Alice
      view |> element("a[href*='registration/edit']") |> render_click()

      assert has_element?(view, "#event-modal")
      assert has_element?(view, "button", "Cancel Registration")

      # Click Cancel Registration
      html = view |> element("button", "Cancel Registration") |> render_click()

      assert html =~ "Registration canceled. Notification sent to Alice Smith"
      refute has_element?(view, "#event-modal")
      refute has_element?(view, "#attendees", "Alice Smith")
    end

    test "edit registration modal link and cancel preserve filter and order query parameters", %{
      conn: conn,
      event: event,
      lang: lang
    } do
      register_attendee(event, "Alice", false, [lang], false, full_name: "Alice Smith")

      {:ok, view, _html} =
        live(conn, ~p"/events/#{event}/hosting/lobby?filter=Alice&order=registration")

      # Click edit button link for Alice
      view |> element("a[href*='registration/edit']") |> render_click()

      assert_patch(
        view,
        ~p"/events/#{event}/hosting/lobby/registration/edit/Alice?filter=Alice&order=registration"
      )

      # Modal should be shown
      assert has_element?(view, "#event-modal")
    end
  end
end
