defmodule DevRoundWeb.HostingLectureLive.Show do
  use DevRoundWeb, :live_view
  use DevRoundWeb.EventSlidesViewerLive, :relay_page_turn_events
  import DevRoundWeb.HostingBase

  alias DevRound.Events
  alias DevRound.Events.Event

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
    DevRoundWeb.Endpoint.subscribe("registrations")
    DevRoundWeb.Endpoint.subscribe("host_actions")
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

  def handle_info(%{topic: "event_slides", payload: %{event_id: event_id, live: live?}}, socket)
      when event_id == socket.assigns.event.id do
    %{event: event} = socket.assigns
    event = %{event | live: live?}
    {:noreply, socket |> assign(:event, event)}
  end

  def handle_info(%{topic: "registrations", payload: %{event: event} = payload}, socket) do
    if event.id == socket.assigns.event.id do
      {:noreply, maybe_registration_toast(socket, payload)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: "host_actions", payload: payload}, socket) do
    {:noreply, maybe_host_action_toast(socket, payload)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_live", %{"live" => live?}, socket) when is_boolean(live?) do
    %{event: event} = socket.assigns
    {:ok, %Event{} = event} = Events.update_event_live(event, live?)
    broadcast_set_live(event, live?)

    broadcast_host_action(event, %{
      action: :set_presentation,
      event_id: event.id,
      live?: live?,
      acting_user: socket.assigns.current_user
    })

    msg = if live?, do: "Presentation started.", else: "Presentation stopped."
    {:noreply, socket |> assign(:event, event) |> put_flash(:info, msg)}
  end

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign_messages()
    |> assign_pdf_url()
  end

  defp broadcast_set_live(event, live?) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_slides", "set_live", %{
      event_id: event.id,
      live: live?
    })
  end

  defp page_title(:show), do: "Hosting Lecture"
end
