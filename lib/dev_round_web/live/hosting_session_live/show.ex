defmodule DevRoundWeb.HostingSessionLive.Show do
  alias DevRound.Events.EventSession
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase
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
      Hosting.build_teams_for_session(session, event.events_attendees, team_names)

    broadcast_teams_build(session)

    {:noreply, socket |> assign_teams()}
  end

  def handle_event("set_live", %{"live" => live?}, socket) when is_boolean(live?) do
    %{session: session, teams: teams} = socket.assigns
    false = Enum.empty?(teams)
    {:ok, %EventSession{} = session} = Events.update_event_session_live(session, live?)
    broadcast_set_live(session, live?)
    {:noreply, socket |> assign(:session, session)}
  end

  def handle_event("reset", _params, socket) do
    %{session: session} = socket.assigns
    {:ok, _} = Events.reset_event_session(session)
    broadcast_reset(session)
    {:noreply, socket |> update_assigns()}
  end

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign_messages()
    |> assign_session()
    |> assign_teams()
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
    socket
    |> assign(:teams, Hosting.list_teams_for_session(socket.assigns.session))
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

  defp broadcast_set_live(event_session, live?) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_sessions", "set_live", %{
      event_session_id: event_session.id,
      live?: live?
    })
  end

  defp broadcast_reset(event_session) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_sessions", "reset", %{
      event_session_id: event_session.id
    })
  end
end
