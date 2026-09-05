defmodule DevRoundWeb.HostingSessionLive.Show do
  alias DevRound.Events.EventSession
  use DevRoundWeb, :live_view
  use DevRoundWeb.EventSessionCountdownLive, :relay_countdown_ticks
  import DevRoundWeb.HostingBase
  alias DevRound.Formats
  alias DevRound.Events
  alias DevRound.Events.Event
  alias DevRound.Hosting

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
    DevRoundWeb.Endpoint.subscribe("registrations")
    DevRoundWeb.Endpoint.subscribe("event_sessions")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug, "session_slug" => session_slug}, _, socket) do
    socket =
      socket
      |> assign(:slug, slug)
      |> assign(:session_slug, session_slug)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({"updated", %Event{} = event}, socket) do
    if event.id == socket.assigns.event.id do
      if event.slug != socket.assigns.event.slug do
        session = socket.assigns.session
        {:noreply, push_patch(socket, to: ~p"/events/#{event}/hosting/session/#{session}")}
      else
        {:noreply, update_assigns(socket)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: "registrations", payload: {_op, event, _attendee}}, socket) do
    if event.id == socket.assigns.event.id do
      {:noreply, update_assigns(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{topic: "event_sessions", event: "teams_built", payload: %{event_session_id: id}},
        socket
      )
      when id == socket.assigns.session.id do
    {:noreply, socket |> assign_teams()}
  end

  def handle_info(
        %{topic: "event_sessions", event: "set_live", payload: %{event_session_id: id}},
        socket
      )
      when id == socket.assigns.session.id do
    {:noreply, socket |> update_assigns()}
  end

  def handle_info(
        %{topic: "event_sessions", event: "reset", payload: %{event_session_id: id}},
        socket
      )
      when id == socket.assigns.session.id do
    {:noreply, socket |> update_assigns()}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("build_teams", _params, socket) do
    %{session: session, event: event, team_names: team_names} = socket.assigns
    false = session.teams_locked

    {:ok, _} =
      Hosting.build_teams_for_session(
        session,
        event.events_attendees,
        team_names,
        event.team_video_conference_rooms
      )

    broadcast_teams_build(session)

    {:noreply,
     socket
     |> assign_teams()
     |> put_flash(:info, "Teams generated. You may start the session now.")}
  end

  def handle_event("start_session", _params, socket) do
    %{event: event, session: session, teams: teams} = socket.assigns
    false = Enum.empty?(teams)
    {:ok, %{event: event, session: session}} = Events.start_event_session(event, session)
    broadcast_set_live(event, session, true)

    msg = "Session \"#{session.title}\" started."

    {:noreply,
     socket
     |> assign(event: event, session: session)
     |> assign_teams()
     |> put_flash(:info, msg)}
  end

  def handle_event(
        "swap_team_members",
        %{"source_member_id" => source_id, "target_member_id" => target_id},
        socket
      ) do
    %{session: session, teams: teams} = socket.assigns

    if session.teams_locked || Enum.empty?(teams) do
      {:noreply, put_flash(socket, :error, "Team adjustments are not allowed at this time.")}
    else
      handle_swap_result(
        Hosting.swap_team_members(session, source_id, target_id),
        session,
        socket
      )
    end
  end

  def handle_event("stop_session", _params, socket) do
    %{event: event, session: session, teams: teams} = socket.assigns
    false = Enum.empty?(teams)
    {:ok, %EventSession{} = session} = Events.stop_event_session(session)
    broadcast_set_live(event, session, false)

    {:noreply,
     socket
     |> assign(:session, session)
     |> put_flash(:info, "Session \"#{session.title}\" stopped.")
     |> push_navigate(to: ~p"/events/#{event}/hosting/lecture")}
  end

  def handle_event("reset", _params, socket) do
    %{event: event, session: session} = socket.assigns
    {:ok, _} = Events.reset_event_session(session)
    broadcast_reset(event, session)

    {:noreply,
     socket |> update_assigns() |> put_flash(:info, "Session reset. You may build new teams now.")}
  end

  defp handle_swap_result({:ok, %{member_a: member_a, member_b: member_b}}, session, socket) do
    broadcast_teams_build(session)

    {:noreply,
     socket
     |> assign_teams()
     |> put_flash(:info, "Swapped #{member_a.user.full_name} and #{member_b.user.full_name}.")}
  end

  defp handle_swap_result({:error, reason}, _session, socket) do
    {:noreply, put_flash(socket, :error, swap_error_message(reason))}
  end

  defp swap_error_message(:teams_locked), do: "Teams are locked. Cannot adjust teams."
  defp swap_error_message(:same_team), do: "Cannot swap members within the same team."
  defp swap_error_message(:remote_mismatch), do: "Cannot swap: Remote status does not match."
  defp swap_error_message(:lang_mismatch), do: "Cannot swap: Incompatible programming languages."
  defp swap_error_message(_), do: "Could not swap team members."

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign_messages()
    |> assign_session()
    |> assign_teams()
    |> assign_dates()
    |> assign_page_title()
  end

  defp assign_session(socket) do
    session_slug = socket.assigns.session_slug

    socket
    |> assign(
      :session,
      Enum.find(socket.assigns.event.sessions, fn session -> session.slug == session_slug end)
    )
  end

  defp assign_teams(socket) do
    teams = Hosting.list_teams_for_session(socket.assigns.session)

    socket
    |> assign(:teams, teams)
    |> assign(
      :allow_adjustments,
      not Enum.empty?(teams) and not socket.assigns.session.teams_locked
    )
  end

  defp assign_dates(socket) do
    event_session = socket.assigns.session
    {:ok, now} = DateTime.now(Formats.time_zone())

    if Date.compare(now, event_session.begin_local) == :eq &&
         Date.compare(event_session.begin_local, event_session.end_local) == :eq do
      socket
      |> assign(:begin, Formats.format_time(event_session.begin_local))
      |> assign(:end_, Formats.format_time(event_session.end_local))
    else
      socket
      |> assign(:begin, Formats.format_datetime(event_session.begin_local))
      |> assign(:end_, Formats.format_datetime(event_session.end_local))
    end
  end

  defp assign_page_title(%{assigns: %{live_action: :show, session: session}} = socket) do
    socket
    |> assign(:page_title, "Hosting #{session.title}")
  end

  defp broadcast_teams_build(event_session) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_sessions", "teams_built", %{
      event_session_id: event_session.id
    })
  end

  defp broadcast_set_live(event, event_session, live?) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_sessions", "set_live", %{
      event_id: event.id,
      event_session_id: event_session.id,
      live?: live?
    })
  end

  defp broadcast_reset(event, event_session) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_sessions", "reset", %{
      event_id: event.id,
      event_session_id: event_session.id
    })
  end
end
