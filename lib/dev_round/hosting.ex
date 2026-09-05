defmodule DevRound.Hosting do
  @moduledoc """
  The Hosting context for team formation and session management.

  Provides functionality for:
  - Team name management
  - Attendee check-in
  - Team generation with experience-based pairing
  - Team name assignment
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Ecto.Changeset
  alias DevRound.Events.EventAttendee
  alias DevRound.Repo

  alias DevRound.Hosting.Team
  alias DevRound.Hosting.TeamMember
  alias DevRound.Hosting.TeamName
  alias DevRound.Events.EventSession

  @doc """
  Returns the list of team_names.

  ## Examples

      iex> list_team_names()
      [%TeamName{}, ...]

  """
  def list_team_names do
    Repo.all(TeamName)
  end

  @doc """
  Gets a single team_name.

  Raises `Ecto.NoResultsError` if the Team name does not exist.

  ## Examples

      iex> get_team_name!(123)
      %TeamName{}

      iex> get_team_name!(456)
      ** (Ecto.NoResultsError)

  """
  def get_team_name!(id), do: Repo.get!(TeamName, id)

  @doc """
  Creates a team_name.

  ## Examples

      iex> create_team_name(%{field: value})
      {:ok, %TeamName{}}

      iex> create_team_name(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_team_name(attrs \\ %{}, opts \\ []) do
    %TeamName{}
    |> TeamName.changeset(attrs)
    |> Repo.insert(opts)
  end

  @doc """
  Updates a team_name.

  ## Examples

      iex> update_team_name(team_name, %{field: new_value})
      {:ok, %TeamName{}}

      iex> update_team_name(team_name, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_team_name(%TeamName{} = team_name, attrs) do
    team_name
    |> TeamName.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team_name.

  ## Examples

      iex> delete_team_name(team_name)
      {:ok, %TeamName{}}

      iex> delete_team_name(team_name)
      {:error, %Ecto.Changeset{}}

  """
  def delete_team_name(%TeamName{} = team_name) do
    Repo.delete(team_name)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team_name changes.

  ## Examples

      iex> change_team_name(team_name)
      %Ecto.Changeset{data: %TeamName{}}

  """
  def change_team_name(%TeamName{} = team_name, attrs \\ %{}) do
    TeamName.changeset(team_name, attrs)
  end

  def update_event_attendee_checked(%EventAttendee{} = attendee, checked) do
    attendee
    |> EventAttendee.check_changeset(%{checked: checked})
    |> Repo.update()
  end

  def change_event_attendee_checked(%EventAttendee{} = attendee, checked) do
    EventAttendee.check_changeset(attendee, %{checked: checked})
  end

  def validate_team_generation_constraints(attendees, team_names, team_rooms) do
    attendees = filter_checked(attendees)

    if Enum.count(attendees) >= 2 do
      messages = build_validation_messages(attendees, team_names, team_rooms)

      case messages do
        [] -> {:ok, []}
        _ -> {:error, messages}
      end
    else
      {:error, ["Not enough checked participants to build teams."]}
    end
  end

  defp build_validation_messages(attendees, team_names, team_rooms) do
    attendee_messages =
      for attendee <- attendees do
        potential_team_mates =
          Enum.filter(attendees, fn other ->
            attendee != other && are_compatible?(attendee, other)
          end)

        if Enum.empty?(potential_team_mates) do
          "No team mate for #{attendee.user.full_name} available wrt. remote status and selected languages."
        else
          nil
        end
      end
      |> Enum.reject(&is_nil/1)

    team_names_message =
      if Integer.floor_div(length(attendees), 2) > length(team_names) do
        ["Not enough team names for checked participants."]
      else
        []
      end

    remote_attendees = Enum.filter(attendees, & &1.is_remote)

    video_conference_rooms_message =
      if Integer.floor_div(length(remote_attendees), 2) > length(team_rooms) do
        [
          "Not enough session video conference room URLs to build teams for checked remote participants."
        ]
      else
        []
      end

    attendee_messages ++ team_names_message ++ video_conference_rooms_message
  end

  defp filter_checked(attendees) do
    Enum.filter(attendees, fn a -> a.checked end)
  end

  defp are_compatible?(%EventAttendee{} = a, %EventAttendee{} = b) do
    a.is_remote == b.is_remote and not MapSet.disjoint?(MapSet.new(a.langs), MapSet.new(b.langs))
  end

  def list_teams_for_session(%EventSession{} = session) do
    member_query =
      from(m in TeamMember, join: u in assoc(m, :user), order_by: [asc: u.full_name])

    from(t in Team, where: t.session_id == ^session.id, order_by: [asc: t.id])
    |> Repo.all()
    |> Repo.preload(:lang)
    |> Repo.preload(members: {member_query, [:user, :langs]})
  end

  @doc """
  Lists all teams for a given user across multiple sessions.
  Returns a map of session_id => team
  """
  def list_teams_for_user_in_sessions(user_id, session_ids) do
    from(t in Team,
      join: m in assoc(t, :members),
      where: t.session_id in ^session_ids and m.user_id == ^user_id
    )
    |> Repo.all()
    |> Repo.preload([:lang, members: [:user, :langs]])
    |> Enum.into(%{}, fn team -> {team.session_id, team} end)
  end

  def build_teams_for_session(%EventSession{} = session, attendees, team_names, team_rooms) do
    attendees = filter_checked(attendees)
    {:ok, []} = validate_team_generation_constraints(attendees, team_names, team_rooms)

    Multi.new()
    |> Multi.delete_all(:teams, Ecto.assoc(session, :teams))
    |> insert_teams(session, attendees, team_names, team_rooms)
    |> Repo.transaction()
  end

  defp insert_teams(multi, session, attendees, team_names, team_rooms) do
    generate_team_changesets(session, attendees, team_names, team_rooms)
    |> Enum.reduce(multi, &Multi.insert(&2, Changeset.get_change(&1, :slug), &1))
  end

  defp generate_team_changesets(session, attendees, team_names, team_rooms) do
    {local_teams, local_langs} = generate_teams_langs(attendees, false)
    {remote_teams, remote_langs} = generate_teams_langs(attendees, true)

    room_urls = team_rooms |> Enum.map(& &1.url)
    local_room_urls = List.duplicate(nil, length(local_teams))
    remote_room_urls = Enum.take(room_urls, length(remote_teams))

    create_team_changesets(
      {local_teams ++ remote_teams, local_langs ++ remote_langs},
      session,
      team_names,
      local_room_urls ++ remote_room_urls
    )
  end

  defp generate_teams_langs(attendees, is_remote) do
    attendees
    |> Enum.filter(&(&1.is_remote == is_remote))
    |> order_attendees_by_experience()
    |> split_experience_field()
    |> find_valid_teams_attendees()
  end

  defp order_attendees_by_experience(attendees) do
    attendees |> Enum.sort_by(&{&1.experience_level, :rand.uniform()})
  end

  defp split_experience_field(attendees) do
    Enum.split(attendees, Enum.count(attendees) |> Integer.floor_div(2))
  end

  defp find_valid_teams_attendees({[], []}) do
    {[], []}
  end

  defp find_valid_teams_attendees({bottom_field, top_field}) do
    {teams_attendees, teams_langs} =
      {bottom_field, top_field}
      |> shuffle_experience_fields()
      |> form_teams_attendees_from_experience_fields()
      |> find_teams_langs()

    if Enum.any?(teams_langs, &Enum.empty?/1) do
      find_valid_teams_attendees({bottom_field, top_field})
    else
      {teams_attendees, teams_langs}
    end
  end

  defp shuffle_experience_fields({bottom_field, top_field}) do
    {Enum.shuffle(bottom_field), Enum.shuffle(top_field)}
  end

  defp form_teams_attendees_from_experience_fields({bottom_field, top_field}) do
    pair_count = min(length(bottom_field), length(top_field)) - 1

    pairs =
      Enum.zip(Enum.take(bottom_field, pair_count), Enum.take(top_field, pair_count))
      |> Enum.map(fn {a, b} -> [a, b] end)

    final_team = Enum.drop(bottom_field, pair_count) ++ Enum.drop(top_field, pair_count)
    pairs ++ [final_team]
  end

  defp find_teams_langs(teams_attendees) do
    langs =
      Enum.map(teams_attendees, fn team_attendees ->
        find_team_langs(team_attendees) |> MapSet.to_list()
      end)

    {teams_attendees, langs}
  end

  defp find_team_langs([attendee | rest]) do
    if Enum.empty?(rest) do
      MapSet.new(attendee.langs)
    else
      MapSet.new(attendee.langs) |> MapSet.intersection(find_team_langs(rest))
    end
  end

  defp find_team_langs([]) do
    MapSet.new()
  end

  defp create_team_changesets({teams_attendees, teams_langs}, session, team_names, room_urls) do
    names = team_names |> Enum.shuffle() |> Enum.take(length(teams_attendees))

    Enum.zip([teams_attendees, teams_langs, names, room_urls])
    |> Enum.map(fn {team_attendees, team_langs, name, room_url} ->
      lang = Enum.random(team_langs)
      is_remote = hd(team_attendees).is_remote

      members =
        Enum.map(team_attendees, fn attendee ->
          %TeamMember{}
          |> Changeset.change(
            is_remote: attendee.is_remote,
            experience_level: attendee.experience_level,
            user: attendee.user
          )
          |> Changeset.put_assoc(:langs, attendee.langs)
        end)

      %Team{}
      |> Changeset.change(
        name: name.name,
        slug: name.slug,
        is_remote: is_remote,
        session: session,
        lang: lang,
        video_conference_room_url: room_url
      )
      |> Changeset.put_assoc(:members, members)
    end)
  end

  @doc """
  Swaps two team members between different teams in a session.
  Checks constraints:
  - Session teams must not be locked
  - Both members must belong to the given session
  - Members must belong to different teams
  - Both teams and members must have matching remote status
  - Both teams must have at least one common language among all members after the swap
  Updates team language to a random valid language if the existing language is no longer valid.
  """
  def swap_team_members(%EventSession{} = session, member_a_id, member_b_id) do
    if session.teams_locked do
      {:error, :teams_locked}
    else
      with {:ok, member_a} <- get_session_team_member(session, member_a_id),
           {:ok, member_b} <- get_session_team_member(session, member_b_id),
           {:ok, %{team_a_valid_langs: langs_a, team_b_valid_langs: langs_b}} <-
             validate_team_member_swap(member_a, member_b) do
        execute_team_member_swap(member_a, member_b, langs_a, langs_b)
      end
    end
  end

  @doc """
  Validates if two team members can be swapped based on constraints:
  - Members must belong to different teams
  - Remote status must match between members and teams
  - Both teams must have at least one common language shared by all members after the swap
  """
  def validate_team_member_swap(%TeamMember{} = member_a, %TeamMember{} = member_b) do
    cond do
      member_a.id == member_b.id or member_a.team_id == member_b.team_id ->
        {:error, :same_team}

      member_a.is_remote != member_b.is_remote or
          member_a.team.is_remote != member_b.team.is_remote ->
        {:error, :remote_mismatch}

      true ->
        team_a_other_members = Enum.reject(member_a.team.members, &(&1.id == member_a.id))
        new_team_a_members = [member_b | team_a_other_members]
        team_a_valid_langs = find_common_langs(new_team_a_members)

        team_b_other_members = Enum.reject(member_b.team.members, &(&1.id == member_b.id))
        new_team_b_members = [member_a | team_b_other_members]
        team_b_valid_langs = find_common_langs(new_team_b_members)

        if Enum.empty?(team_a_valid_langs) or Enum.empty?(team_b_valid_langs) do
          {:error, :lang_mismatch}
        else
          {:ok, %{team_a_valid_langs: team_a_valid_langs, team_b_valid_langs: team_b_valid_langs}}
        end
    end
  end

  defp get_session_team_member(session, member_id) do
    case Repo.get(TeamMember, member_id)
         |> Repo.preload([:langs, :user, team: [:session, :lang, members: [:langs]]]) do
      %TeamMember{team: %Team{session_id: session_id}} = member when session_id == session.id ->
        {:ok, member}

      _ ->
        {:error, :member_not_found}
    end
  end

  defp find_common_langs([member | rest]) do
    member_langs = MapSet.new(member.langs, & &1.id)

    common_lang_ids =
      Enum.reduce(rest, member_langs, fn other_member, acc ->
        MapSet.intersection(acc, MapSet.new(other_member.langs, & &1.id))
      end)

    Enum.filter(member.langs, &MapSet.member?(common_lang_ids, &1.id))
  end

  defp execute_team_member_swap(member_a, member_b, team_a_valid_langs, team_b_valid_langs) do
    team_a = member_a.team
    team_b = member_b.team

    multi =
      Multi.new()
      |> Multi.update(:member_a, Changeset.change(member_a, team_id: team_b.id))
      |> Multi.update(:member_b, Changeset.change(member_b, team_id: team_a.id))

    multi =
      if Enum.any?(team_a_valid_langs, &(&1.id == team_a.lang_id)) do
        multi
      else
        new_lang = Enum.random(team_a_valid_langs)
        Multi.update(multi, :team_a, Changeset.change(team_a, lang_id: new_lang.id))
      end

    multi =
      if Enum.any?(team_b_valid_langs, &(&1.id == team_b.lang_id)) do
        multi
      else
        new_lang = Enum.random(team_b_valid_langs)
        Multi.update(multi, :team_b, Changeset.change(team_b, lang_id: new_lang.id))
      end

    Repo.transaction(multi)
  end
end
