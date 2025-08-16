defmodule DevRoundWeb.HostingSessionLive.Show do
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase
  alias DevRound.Hosting

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("events")
    DevRoundWeb.Endpoint.subscribe("registrations")
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

  @impl true
  def handle_event("build_teams", _params, socket) do
    {:ok, _} =
      Hosting.build_teams_for_session(
        socket.assigns.session,
        socket.assigns.event.events_attendees,
        socket.assigns.team_names
      )

    {:noreply, socket |> assign_teams()}
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
end
