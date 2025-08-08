defmodule DevRoundWeb.HostingSessionLive.Show do
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase

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

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_session()
    |> ensure_current_user_is_host!()
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

  defp assign_page_title(%{assigns: %{live_action: :show, session: session}} = socket) do
    socket
    |> assign(:page_title, "Hosting #{session.title}")
  end
end
