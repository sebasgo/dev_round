defmodule DevRound.HostingTest do
  use DevRound.DataCase

  alias DevRound.Hosting
  alias DevRound.Hosting.TeamName
  alias DevRound.Events

  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  defp team_name_fixture(attrs \\ %{}) do
    {:ok, team_name} =
      attrs
      |> Enum.into(%{
        name: "some name #{System.unique_integer()}"
      })
      |> Hosting.create_team_name()

    team_name
  end

  describe "team_names" do
    test "list_team_names/0 returns all team_names" do
      team_name = team_name_fixture()
      assert team_name in Hosting.list_team_names()
    end

    test "get_team_name!/1 returns the team_name with given id" do
      team_name = team_name_fixture()
      assert Hosting.get_team_name!(team_name.id) == team_name
    end

    test "create_team_name/1 with valid data creates a team_name" do
      # Note: Slug is auto-generated from name
      valid_attrs = %{name: "Special Name"}

      assert {:ok, %TeamName{} = team_name} = Hosting.create_team_name(valid_attrs)
      assert team_name.name == "Special Name"
      assert team_name.slug == "special-name"
    end

    test "create_team_name/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Hosting.create_team_name(%{name: nil})
    end

    test "update_team_name/2 with valid data updates the team_name" do
      team_name = team_name_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %TeamName{} = team_name} = Hosting.update_team_name(team_name, update_attrs)
      assert team_name.name == "some updated name"
    end

    test "update_team_name/2 with invalid data returns error changeset" do
      team_name = team_name_fixture()
      assert {:error, %Ecto.Changeset{}} = Hosting.update_team_name(team_name, %{name: nil})
      assert team_name == Hosting.get_team_name!(team_name.id)
    end

    test "delete_team_name/1 deletes the team_name" do
      team_name = team_name_fixture()
      assert {:ok, %TeamName{}} = Hosting.delete_team_name(team_name)
      assert_raise Ecto.NoResultsError, fn -> Hosting.get_team_name!(team_name.id) end
    end

    test "change_team_name/1 returns a team_name changeset" do
      team_name = team_name_fixture()
      assert %Ecto.Changeset{} = Hosting.change_team_name(team_name)
    end
  end

  describe "attendee check-in" do
    setup do
      # begin_local in fixture is +1 day, so deadline must be earlier than that but in future
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      user = user_fixture()

      {:ok, attendee} =
        Events.create_event_attendee(event, user, %{"lang_ids" => [Enum.at(event.langs, 0).id]})

      {:ok, attendee: attendee}
    end

    test "update_event_attendee_checked/2", %{attendee: attendee} do
      assert {:ok, updated} = Hosting.update_event_attendee_checked(attendee, true)
      assert updated.checked == true
    end

    test "change_event_attendee_checked/2", %{attendee: attendee} do
      assert %Ecto.Changeset{} = Hosting.change_event_attendee_checked(attendee, true)
    end
  end

  describe "team generation" do
    setup do
      lang1 = lang_fixture(%{name: "Elixir"})
      lang2 = lang_fixture(%{name: "Python"})
      lang3 = lang_fixture(%{name: "C++"})

      # begin_local in fixture is +1 day, so deadline must be earlier than that but in future
      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)

      event =
        event_fixture(%{
          put_langs: [lang1, lang2, lang3],
          registration_deadline_local: future_deadline
        })

      session = Enum.at(event.sessions, 0)

      # Create some team names
      for i <- 1..10, do: team_name_fixture(%{name: "Team #{i}"})
      team_names = Hosting.list_team_names()

      {:ok,
       event: event,
       session: session,
       lang1: lang1,
       lang2: lang2,
       lang3: lang3,
       team_names: team_names}
    end

    defp register_attendee(event, name, is_remote, langs, checked \\ true, experience \\ nil) do
      experience = experience || Enum.random(0..9)

      user =
        user_fixture(%{
          name: name,
          full_name: name,
          email: "#{name}@example.com",
          experience_level: experience
        })

      {:ok, attendee} =
        Events.create_event_attendee(event, user, %{
          "is_remote" => is_remote,
          "lang_ids" => Enum.map(langs, & &1.id)
        })

      {:ok, updated} = Hosting.update_event_attendee_checked(attendee, checked)

      # Reload to have preloaded user and langs as expected by Hosting functions
      Repo.get!(Events.EventAttendee, updated.id)
      |> Repo.preload([:user, :langs])
    end

    test "team formation rules", %{
      event: event,
      session: session,
      lang1: lang1,
      lang2: lang2,
      lang3: lang3,
      team_names: team_names
    } do
      # Rules:
      # 1. Remote participants are put in into remote teams, and vice-versa for non-remote attendees.
      # 2. Teams have two members, unless an odd number of participants needs to be assigned. Then there is one team with three members
      # 3. Teams have an assigned programming language which is compatible with each attendee
      # 4. Pair experienced with less experienced attendees

      # 5 remote participants - ALL share lang1
      # Levels: 0, 1, 6, 8, 9
      r1 = register_attendee(event, "r1", true, [lang1], true, 0)
      r2 = register_attendee(event, "r2", true, [lang1, lang2], true, 1)
      r3 = register_attendee(event, "r3", true, [lang1, lang3], true, 6)
      r4 = register_attendee(event, "r4", true, [lang1, lang2, lang3], true, 8)
      r5 = register_attendee(event, "r5", true, [lang1], true, 9)

      # 5 in-person participants - ALL share lang2
      # Levels: 0, 1, 6, 8, 9
      l1 = register_attendee(event, "l1", false, [lang2], true, 0)
      l2 = register_attendee(event, "l2", false, [lang1, lang2], true, 1)
      l3 = register_attendee(event, "l3", false, [lang2, lang3], true, 6)
      l4 = register_attendee(event, "l4", false, [lang1, lang2, lang3], true, 8)
      l5 = register_attendee(event, "l5", false, [lang2], true, 9)

      # Some unchecked attendees
      u1_remote = register_attendee(event, "u1-remote", true, [lang1], false)
      u2_local = register_attendee(event, "u2-local", false, [lang2], false)

      attendees = [r1, r2, r3, r4, r5, l1, l2, l3, l4, l5, u1_remote, u2_local]

      # We need at least as many rooms as remote teams (5 remote -> 3 teams needed: 2 + 3, wait, 5 remote? `Integer.floor_div(5, 2) = 2`? No, 5 remote participants in 2 categories (Split into [A, B] and [C, D, E])), wait `order_attendees_by_experience` sorts them first.
      # 5 remote participants -> 3 teams. 3 rooms needed.
      team_rooms =
        for _ <- 1..3, do: %DevRound.Events.TeamVideoConferenceRoom{url: "http://room.com"}

      assert {:ok, _} =
               Hosting.build_teams_for_session(session, attendees, team_names, team_rooms)

      teams = Hosting.list_teams_for_session(session)

      # Total 10 checked participants. 2 categories (Remote/In-person)
      # In each category: 5 participants -> 1 team of 2 members, 1 team of 3 members
      assert length(teams) == 4

      remote_teams = Enum.filter(teams, & &1.is_remote)
      local_teams = Enum.filter(teams, &(!&1.is_remote))

      assert length(remote_teams) == 2
      assert length(local_teams) == 2

      # Check team sizes
      assert Enum.count(remote_teams, &(length(&1.members) == 2)) == 1
      assert Enum.count(remote_teams, &(length(&1.members) == 3)) == 1
      assert Enum.count(local_teams, &(length(&1.members) == 2)) == 1
      assert Enum.count(local_teams, &(length(&1.members) == 3)) == 1

      # Check language compatibility and experience pairing
      for team <- teams do
        team_lang = team.lang.id
        levels = Enum.map(team.members, & &1.experience_level) |> Enum.sort()

        # Verify all members share the team language and remote status
        for member <- team.members do
          assert member.is_remote == team.is_remote
          member_lang_ids = Enum.map(member.langs, & &1.id)
          assert team_lang in member_lang_ids
        end

        # Verify experience pairing:
        # bottom=[0, 1], top=[6, 8, 9]
        # In ALL teams, we should have at least one "low" (<= 1) AND at least one "high" (>= 6)
        assert Enum.any?(levels, &(&1 <= 1)),
               "Team #{team.name} has no low experience member: #{inspect(levels)}"

        assert Enum.any?(levels, &(&1 >= 6)),
               "Team #{team.name} has no high experience member: #{inspect(levels)}"
      end

      # Verify unchecked attendees are NOT in any team
      team_user_ids =
        teams
        |> Enum.flat_map(& &1.members)
        |> Enum.map(& &1.user_id)
        |> MapSet.new()

      refute MapSet.member?(team_user_ids, u1_remote.user_id)
      refute MapSet.member?(team_user_ids, u2_local.user_id)
    end

    test "error conditions", %{event: event, team_names: team_names, lang1: lang1, lang2: lang2} do
      # 1. Not enough checked participants
      u1 = register_attendee(event, "u1", false, [lang1])

      assert {:error, ["Not enough checked participants to build teams."]} =
               Hosting.validate_team_generation_constraints([u1], team_names, [])

      # 2. No compatible mate (different remote status)
      u2 = register_attendee(event, "u2", true, [lang1])

      assert {:error, messages} =
               Hosting.validate_team_generation_constraints([u1, u2], team_names, [])

      assert Enum.any?(messages, fn m -> m =~ "No team mate for u1" end)
      assert Enum.any?(messages, fn m -> m =~ "No team mate for u2" end)

      # 3. No compatible mate (no common languages)
      u3 = register_attendee(event, "u3", false, [lang2])

      assert {:error, messages} =
               Hosting.validate_team_generation_constraints([u1, u3], team_names, [])

      assert Enum.any?(messages, fn m -> m =~ "No team mate for u1" end)

      # 4. Not enough team names
      u4 = register_attendee(event, "u4", false, [lang1])
      # 3 checked in-person, needs 1 team. 1 remote (u2), not enough.
      # Total 4. Needs 2 teams.
      assert {:error, messages} =
               Hosting.validate_team_generation_constraints(
                 [u1, u3, u4, u2],
                 [hd(team_names)],
                 []
               )

      assert Enum.member?(messages, "Not enough team names for checked participants.")

      # 5. Not enough video conference rooms (needs 1 team for u2)
      assert {:error, messages} =
               Hosting.validate_team_generation_constraints(
                 [u2, register_attendee(event, "u5", true, [lang1])],
                 team_names,
                 []
               )

      assert Enum.member?(
               messages,
               "Not enough session video conference room URLs to build teams for checked remote participants."
             )
    end
  end
end
