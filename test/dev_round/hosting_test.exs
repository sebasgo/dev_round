defmodule DevRound.HostingTest do
  use DevRound.DataCase

  alias DevRound.Hosting
  alias DevRound.Hosting.TeamName
  alias DevRound.Events

  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures
  import DevRound.HostingFixtures

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

  describe "swap_team_members/3" do
    setup do
      lang1 = lang_fixture(%{name: "Elixir"})
      lang2 = lang_fixture(%{name: "Python"})
      lang3 = lang_fixture(%{name: "C++"})

      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)

      event =
        event_fixture(%{
          put_langs: [lang1, lang2, lang3],
          registration_deadline_local: future_deadline
        })

      session = Enum.at(event.sessions, 0)

      for i <- 1..5, do: team_name_fixture(%{name: "Team #{i}"})
      team_names = Hosting.list_team_names()

      {:ok,
       event: event,
       session: session,
       lang1: lang1,
       lang2: lang2,
       lang3: lang3,
       team_names: team_names}
    end

    test "successfully swaps compatible team members between teams", %{
      event: event,
      session: session,
      lang1: lang1,
      lang2: lang2,
      team_names: team_names
    } do
      # All 4 participants know both lang1 and lang2
      a1 = register_attendee(event, "a1", false, [lang1, lang2], true, 1)
      a2 = register_attendee(event, "a2", false, [lang1, lang2], true, 9)
      b1 = register_attendee(event, "b1", false, [lang1, lang2], true, 2)
      b2 = register_attendee(event, "b2", false, [lang1, lang2], true, 8)

      attendees = [a1, a2, b1, b2]
      assert {:ok, _} = Hosting.build_teams_for_session(session, attendees, team_names, [])

      teams = Hosting.list_teams_for_session(session)
      assert length(teams) == 2
      [team1, team2] = teams

      member_a = hd(team1.members)
      member_b = hd(team2.members)

      assert {:ok, %{member_a: updated_a, member_b: updated_b}} =
               Hosting.swap_team_members(session, member_a.id, member_b.id)

      assert updated_a.team_id == team2.id
      assert updated_b.team_id == team1.id

      # Verify persisted teams have updated members
      teams_after = Hosting.list_teams_for_session(session)
      team1_after = Enum.find(teams_after, &(&1.id == team1.id))
      team2_after = Enum.find(teams_after, &(&1.id == team2.id))

      assert member_b.id in Enum.map(team1_after.members, & &1.id)
      assert member_a.id in Enum.map(team2_after.members, & &1.id)
      refute member_a.id in Enum.map(team1_after.members, & &1.id)
      refute member_b.id in Enum.map(team2_after.members, & &1.id)
    end

    test "rejects swap when session teams are locked", %{
      event: event,
      session: session,
      lang1: lang1,
      team_names: team_names
    } do
      a1 = register_attendee(event, "a1", false, [lang1], true)
      a2 = register_attendee(event, "a2", false, [lang1], true)
      b1 = register_attendee(event, "b1", false, [lang1], true)
      b2 = register_attendee(event, "b2", false, [lang1], true)

      assert {:ok, _} = Hosting.build_teams_for_session(session, [a1, a2, b1, b2], team_names, [])
      [team1, team2] = Hosting.list_teams_for_session(session)

      locked_session = %{session | teams_locked: true}

      assert {:error, :teams_locked} =
               Hosting.swap_team_members(
                 locked_session,
                 hd(team1.members).id,
                 hd(team2.members).id
               )
    end

    test "rejects swap when members are in the same team", %{
      event: event,
      session: session,
      lang1: lang1,
      team_names: team_names
    } do
      a1 = register_attendee(event, "a1", false, [lang1], true)
      a2 = register_attendee(event, "a2", false, [lang1], true)
      b1 = register_attendee(event, "b1", false, [lang1], true)
      b2 = register_attendee(event, "b2", false, [lang1], true)

      assert {:ok, _} = Hosting.build_teams_for_session(session, [a1, a2, b1, b2], team_names, [])
      [team1, _team2] = Hosting.list_teams_for_session(session)

      [m1, m2] = team1.members
      assert {:error, :same_team} = Hosting.swap_team_members(session, m1.id, m2.id)
    end

    test "rejects swap when remote status does not match", %{
      event: event,
      session: session,
      lang1: lang1,
      team_names: team_names
    } do
      r1 = register_attendee(event, "r1", true, [lang1], true)
      r2 = register_attendee(event, "r2", true, [lang1], true)
      l1 = register_attendee(event, "l1", false, [lang1], true)
      l2 = register_attendee(event, "l2", false, [lang1], true)

      team_rooms = [%DevRound.Events.TeamVideoConferenceRoom{url: "http://room.com"}]

      assert {:ok, _} =
               Hosting.build_teams_for_session(session, [r1, r2, l1, l2], team_names, team_rooms)

      teams = Hosting.list_teams_for_session(session)
      remote_team = Enum.find(teams, & &1.is_remote)
      local_team = Enum.find(teams, &(!&1.is_remote))

      assert {:error, :remote_mismatch} =
               Hosting.swap_team_members(
                 session,
                 hd(remote_team.members).id,
                 hd(local_team.members).id
               )
    end

    test "updates team languages when swapping partners share different common languages", %{
      event: _event,
      session: session,
      lang1: lang1,
      lang2: lang2,
      lang3: lang3
    } do
      user_a1 = user_fixture(%{name: "a1", full_name: "a1"})
      user_a2 = user_fixture(%{name: "a2", full_name: "a2"})
      user_b1 = user_fixture(%{name: "b1", full_name: "b1"})
      user_b2 = user_fixture(%{name: "b2", full_name: "b2"})

      # Team 1: lang1 (Elixir). Members: a1 [lang1, lang3], a2 [lang1, lang2]
      # Team 2: lang2 (Python). Members: b1 [lang2, lang3], b2 [lang2, lang3]
      team1 =
        %DevRound.Hosting.Team{}
        |> Ecto.Changeset.change(%{
          name: "Team 1",
          slug: "team-1",
          is_remote: false,
          session_id: session.id,
          lang_id: lang1.id
        })
        |> Ecto.Changeset.put_assoc(:members, [
          %DevRound.Hosting.TeamMember{
            is_remote: false,
            experience_level: 1,
            user_id: user_a1.id
          }
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:langs, [lang1, lang3]),
          %DevRound.Hosting.TeamMember{
            is_remote: false,
            experience_level: 9,
            user_id: user_a2.id
          }
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:langs, [lang1, lang2])
        ])
        |> Repo.insert!()

      team2 =
        %DevRound.Hosting.Team{}
        |> Ecto.Changeset.change(%{
          name: "Team 2",
          slug: "team-2",
          is_remote: false,
          session_id: session.id,
          lang_id: lang2.id
        })
        |> Ecto.Changeset.put_assoc(:members, [
          %DevRound.Hosting.TeamMember{
            is_remote: false,
            experience_level: 1,
            user_id: user_b1.id
          }
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:langs, [lang2, lang3]),
          %DevRound.Hosting.TeamMember{
            is_remote: false,
            experience_level: 9,
            user_id: user_b2.id
          }
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:langs, [lang2, lang3])
        ])
        |> Repo.insert!()

      member_a1 = Enum.find(team1.members, &(&1.user_id == user_a1.id))
      member_b1 = Enum.find(team2.members, &(&1.user_id == user_b1.id))

      assert {:ok, _} = Hosting.swap_team_members(session, member_a1.id, member_b1.id)

      teams_after = Hosting.list_teams_for_session(session)
      team1_after = Enum.find(teams_after, &(&1.id == team1.id))
      team2_after = Enum.find(teams_after, &(&1.id == team2.id))

      # Team 1 had lang1; now has a2 [lang1, lang2] + b1 [lang2, lang3] -> only lang2
      assert team1_after.lang_id == lang2.id
      # Team 2 had lang2; now has b2 [lang2, lang3] + a1 [lang1, lang3] -> only lang3
      assert team2_after.lang_id == lang3.id
    end

    test "rejects swap when languages do not match", %{
      event: event,
      session: session,
      lang1: lang1,
      lang2: lang2,
      team_names: team_names
    } do
      # Team 1 will be only lang1
      a1 = register_attendee(event, "a1", false, [lang1], true, 1)
      a2 = register_attendee(event, "a2", false, [lang1], true, 9)
      # Team 2 will be only lang2
      b1 = register_attendee(event, "b1", false, [lang2], true, 1)
      b2 = register_attendee(event, "b2", false, [lang2], true, 9)

      assert {:ok, _} = Hosting.build_teams_for_session(session, [a1, a2, b1, b2], team_names, [])

      [team1, team2] = Hosting.list_teams_for_session(session)
      m1 = hd(team1.members)
      m2 = hd(team2.members)

      assert {:error, :lang_mismatch} = Hosting.swap_team_members(session, m1.id, m2.id)
    end
  end
end
