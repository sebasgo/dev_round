defmodule DevRoundWeb.EventLive.Show do

  use DevRoundWeb, :live_view

  alias DevRound.Events

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("events")
    DevRoundWeb.Endpoint.subscribe("registrations")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    socket = socket
    |> assign(:slug, slug)
    |> update_assigns()
    if socket.assigns.live_action in [:new_registration, :edit_registration] and !socket.assigns.registration_open? do
      {:noreply, socket
        |> put_flash(:error, "Registration for this event is closed.")
        |> push_patch(to: ~p"/events/#{socket.assigns.event}")}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def  handle_info({"event_updated", event}, socket) do
    if event.id == socket.assigns.event.id do
      socket = put_flash(socket, :info, "This page has been reloaded to reflect the latest update.")
      {:noreply, update_assigns(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{topic: "registrations", payload: {_op, event, _attendee}}, socket) do
    if event.id == socket.assigns.event.id do
      {:noreply, update_assigns(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_assigns(socket) do
    slug  = socket.assigns.slug
    event = Events.get_event!(slug)
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, event))
    |> assign(:event, event)
    |> assign(:attendence, attendence(event, socket.assigns.current_user))
    |> assign(:registration_open?, Events.event_open_for_registration?(event))
  end

  defp page_title(:show, event), do: event.title
  defp page_title(:new_registration, event), do: "#{event.title} · Register"
  defp page_title(:edit_registration, event), do: "#{event.title} · Manage Registration"

  defp attendence(event, user) do
    Enum.find(event.events_attendees, fn a -> a.user.id == user.id end)
  end
end
