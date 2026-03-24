defmodule DevRoundWeb.EventLive.Index do
  use DevRoundWeb, :live_view

  alias DevRound.Events

  @impl true
  def mount(_params, _session, socket) do
    current_events = Events.list_events(:current)
    archived_events = Events.list_events(:archived)
    {:ok, assign(socket, current_events: current_events, archived_events: archived_events)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
