defmodule DevRoundWeb.EventLive.Index do
  use DevRoundWeb, :live_view

  alias DevRound.Events

  @impl true
  def mount(_params, _session, socket) do
    current_events = Events.list_events(:current)
    archived_events = Events.list_events(:archived)

    {:ok,
     assign(socket,
       current_events: current_events,
       archived_events: archived_events,
       search_form: to_form(%{"query" => ""}),
       search_results: nil
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query} = search_params, socket) do
    {:noreply,
     assign(socket, form: to_form(search_params), search_results: search_for_events(query))}
  end

  defp search_for_events("" = _query), do: nil
  defp search_for_events(query) when is_binary(query), do: Events.search_for_events(query)
end
