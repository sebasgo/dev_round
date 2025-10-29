defmodule DevRoundWeb.EventSlidesLive.Show do
  use DevRoundWeb, :live_view
  use DevRoundWeb.EventSlidesViewerLive, :relay_page_turn_events

  alias DevRound.Events
  alias DevRound.Events.Event

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
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


  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_assigns(socket) do
    slug = socket.assigns.slug
    event = Events.get_event!(slug)

    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:event, event)
    |> assign_pdf_url()
  end

  defp page_title(:show), do: "Event Slides"
end
