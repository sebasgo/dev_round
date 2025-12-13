defmodule DevRoundWeb.EventSlidesLive.Show do
  use DevRoundWeb, :live_view
  use DevRoundWeb.EventSlidesViewerLive, :relay_page_turn_events
  use DevRoundWeb.EventSessionCountdownLive, :relay_countdown_ticks

  alias DevRound.Events
  alias DevRound.Events.Event

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
    DevRoundWeb.Endpoint.subscribe("event_sessions")
    subscribe_to_page_turn_topic()
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    socket =
      socket
      |> assign(:slug, slug)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({"updated", %Event{} = event}, socket) do
    if event.id == socket.assigns.event.id do
      if event.slug != socket.assigns.event.slug do
        {:noreply, push_patch(socket, to: ~p"/events/#{event}/hosting/lecture")}
      else
        {:noreply, update_assigns(socket)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: "event_slides", payload: %{event_id: event_id}}, socket)
      when event_id == socket.assigns.event.id do
    {:noreply, socket |> update_assigns()}
  end

  def handle_info(
        %{topic: "event_sessions", event: "set_live", payload: %{event_id: id}},
        socket
      )
      when id == socket.assigns.event.id do
    {:noreply, socket |> update_assigns(true)}
  end

  def handle_info(
        %{topic: "event_sessions", event: "reset", payload: %{event_id: id}},
        socket
      )
      when id == socket.assigns.event.id do
    {:noreply, socket |> update_assigns()}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_assigns(socket, new_session? \\ false) do
    slug = socket.assigns.slug
    event = Events.get_event!(slug)

    session =
      if event.last_live_session != nil and event.last_live_session.live,
        do: event.last_live_session,
        else: nil

    socket
    |> assign(:page_title, page_title(event, socket.assigns.live_action))
    |> assign(:event, event)
    |> assign(:session, session)
    |> assign(:new_session?, new_session?)
    |> assign(:multiple_langs, not Enum.empty?(tl(event.langs)))
    |> assign_pdf_url()
  end

  defp page_title(event, :show), do: "Live Presentation · #{event.title}"
end
