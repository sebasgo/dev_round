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
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:id, id)
     |> update_assigns()}
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
    id  = socket.assigns.id
    event = Events.get_event!(id)
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, event))
    |> assign(:event, event)
    |> assign(:attendence, attendence(event, socket.assigns.current_user))
  end

  defp page_title(:show, event), do: event.title
  defp page_title(:new_registration, event), do: "#{event.title} · Register"
  defp page_title(:edit_registration, event), do: "#{event.title} · Manage Registration"

  defp attendence(event, user) do
    Enum.find(event.events_attendees, fn a -> a.user.id == user.id end)
  end
end
