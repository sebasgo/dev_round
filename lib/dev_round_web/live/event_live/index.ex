defmodule DevRoundWeb.EventLive.Index do
  use DevRoundWeb, :live_view

  alias DevRound.Events

  @impl true
  def mount(_params, _session, socket) do
    upcoming_events = Events.list_events(:upcoming)
    past_events = Events.list_events(:past)
    {:ok, assign(socket, upcoming_events: upcoming_events, past_events: past_events)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def event_list(assigns) do
    ~H"""
    <div class="mb-12">
      <div class="flex items-center gap-3 mb-6">
        <div class={"badge badge-#{@accent_class} badge-lg"}>
          {length(@events)}
        </div>
        <h2 class="text-2xl font-mono font-semibold text-base-content">{@title}</h2>
      </div>

      <%= if @events == [] do %>
        {render_slot(@placeholder)}
      <% else %>
        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <%= for event <- @events do %>
            <.link
              patch={~p"/events/#{event}"}
              class="card bg-base-100 shadow-md hover:shadow-lg transition-shadow duration-200 border border-base-300 hover:border-primary/20"
            >
              <div class="card-body">
                <h3 class="card-title text-lg font-mono font-semibold text-base-content">
                  {event.title}
                </h3>

                <p class="mt-3 text-sm">{event.teaser}</p>

                <div class="flex flex-col gap-2 mt-3">
                  <div class="flex items-center gap-2 text-sm text-base-content/70">
                    <.icon name="hero-calendar" class="w-4 h-4" />
                    {DevRound.Formats.format_datetime_range(
                      event.begin |> DateTime.shift_zone!(DevRound.Formats.time_zone()),
                      event.end |> DateTime.shift_zone!(DevRound.Formats.time_zone())
                    )}
                  </div>

                  <div class="flex items-center gap-2 text-sm text-base-content/70">
                    <.icon name="hero-map-pin" class="w-4 h-4" />
                    {event.location}
                  </div>
                </div>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
