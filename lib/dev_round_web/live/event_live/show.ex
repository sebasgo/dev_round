defmodule DevRoundWeb.EventLive.Show do
  use DevRoundWeb, :live_view

  alias DevRound.Events

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("events")
    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), any(), map()) :: {:noreply, map()}
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

  def  handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_assigns(socket) do
    id  = socket.assigns.id
    event = Events.get_event!(id)
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, event))
    |> assign(:event, event)
  end

  defp page_title(:show, event), do: event.title
  defp page_title(:edit, event), do: "#{event.title} · Edit"
end
