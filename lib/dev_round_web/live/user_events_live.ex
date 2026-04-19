defmodule DevRoundWeb.UserEventsLive do
  use DevRoundWeb, :live_view
  use DevRoundWeb.EventSessionCountdownLive, :relay_countdown_ticks

  alias DevRound.Events
  alias DevRound.Events.Event
  alias DevRoundWeb.Layouts

  def mount(_params, _session, socket) do
    if connected?(socket) do
      DevRoundWeb.Endpoint.subscribe("registrations")
      DevRoundWeb.Endpoint.subscribe("admin.events")
      DevRoundWeb.Endpoint.subscribe("event_sessions")

      # Schedule midnight rollover check
      schedule_midnight_check()
    end

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    expanded_ids =
      case params["expanded"] do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
        _ -> []
      end
      |> Enum.map(&String.to_integer/1)
      |> MapSet.new()

    {:noreply,
     socket
     |> assign(:expanded_ids, expanded_ids)
     |> assign_events()}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Your Events
        <:subtitle>
          Track and organize your event registrations
        </:subtitle>
      </.header>

      <div class="space-y-16">
        <%!-- underway Section --%>
        <section :if={Enum.any?(@underway_events)} id="underway-events">
          <h2 class="text-2xl font-mono font-semibold mb-6">
            Up Next
          </h2>
          <div class="grid grid-cols-1 gap-8">
            <.event_card
              :for={event <- @underway_events}
              event={event}
              teams_map={@teams_map}
              show_video_conference_room_url={true}
            />
          </div>
        </section>

        <%!-- Upcoming Section --%>
        <section :if={Enum.any?(@upcoming_events)} id="upcoming-events">
          <DevRoundWeb.EventComponents.event_grid_listing
            events={@upcoming_events}
            title="Future Events"
            accent_class="neutral"
          />
        </section>

        <%!-- Archived Section --%>
        <section :if={Enum.any?(@archived_events)} id="archived-events">
          <div class="flex items-center gap-3 mb-6">
            <h2 class="text-2xl font-mono font-semibold text-base-content">Archived Events</h2>
            <div class="badge badge-neutral badge-lg">
              {length(@archived_events)}
            </div>
          </div>
          <div class="grid grid-cols-1 gap-8">
            <.event_card
              :for={event <- @archived_events}
              event={event}
              teams_map={@teams_map}
              collapsable={true}
              expanded={MapSet.member?(@expanded_ids, event.id)}
            />
          </div>
        </section>

        <DevRoundWeb.EventComponents.content_placeholder
          :if={not Enum.any?(@underway_events ++ @upcoming_events ++ @archived_events)}
          title="No registrations found."
        >
          Check out the <.link patch={~p"/events"} class="link">events page</.link>
          to find your first event!
        </DevRoundWeb.EventComponents.content_placeholder>
      </div>
    </Layouts.app>
    """
  end

  attr :event, Event, required: true
  attr :teams_map, :map, required: true
  attr :collapsable, :boolean, default: false
  attr :expanded, :boolean, default: true
  attr :show_video_conference_room_url, :boolean, default: false

  defp event_card(assigns) do
    ~H"""
    <div class="rounded-lg shadow-lg overflow-hidden border border-base-content/10 -mx-4">
      <div class="grid grid-cols-1 md:grid-cols-[1fr_auto] items-start gap-4 p-4 bg-base-300">
        <div class="grow">
          <h3 class="text-lg font-mono font-semibold text-base-content">
            <.link patch={~p"/events/#{@event.slug}"}>
              {@event.title}
            </.link>
          </h3>
          <p class="mt-3 text-sm">{@event.teaser}</p>
          <div class="flex flex-wrap gap-4 mt-3 text-sm text-base-content/70">
            <span class="flex items-center gap-1">
              <.icon name="hero-calendar" />
              {DevRound.Formats.format_datetime_range(@event.begin_local, @event.end_local)}
            </span>
            <span class="flex items-center gap-1">
              <.icon name="hero-map-pin" /> {@event.location}
            </span>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <button
            :if={@collapsable}
            phx-click={toggle_expand(@expanded, @event.id)}
            class="btn btn-neutral"
          >
            <.icon name={if @expanded, do: "hero-chevron-up", else: "hero-chevron-down"} />
            {if @expanded, do: "Hide Sessions", else: "Show Sessions"}
          </button>
          <.button patch={~p"/events/#{@event.slug}"} variant="primary">
            View Event
          </.button>
        </div>
      </div>
      <div
        :if={@expanded}
        class="grid grid-cols-1 md:grid-cols-[2fr_1fr] justify-between items-stretch gap-4 p-4 bg-black/40 border-t border-base-content/10"
      >
        <h4 class="md:col-span-2 font-mono font-semibold flex items-center gap-2 text-sm uppercase tracking-wider opacity-60">
          <.icon name="hero-list-bullet" class="size-4" /> Sessions & Teams
        </h4>
        <%= for session <- @event.sessions do %>
          <div class="bg-base-200/50 rounded-lg overflow-hidden border border-base-content/5">
            <DevRoundWeb.EventComponents.session session={session} />
          </div>
          <div class="flex flex-col justify-center">
            <%= if Map.has_key?(@teams_map, session.id) do %>
              <DevRoundWeb.EventComponents.team
                team={Map.get(@teams_map, session.id)}
                show_member_experience_level={false}
                show_member_langs={false}
                multiple_langs={tl(@event.langs) != []}
                show_video_conference_room_url={@show_video_conference_room_url}
                class="border border-base-content/5"
              />
            <% else %>
              <div class="flex items-center p-4 text-base-content/70 text-center text-sm italic">
                <%= if session.teams_locked do %>
                  The teams for this session have not been assigned yet.
                <% else %>
                  You did not take part in this session.
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp toggle_expand(expanded, event_id) do
    JS.push("toggle_expand", value: %{id: event_id, expanded: expanded})
  end

  def handle_event("toggle_expand", %{"id" => id, "expanded" => expanded}, socket) do
    expanded_ids =
      if expanded do
        MapSet.delete(socket.assigns.expanded_ids, id)
      else
        MapSet.put(socket.assigns.expanded_ids, id)
      end

    params =
      if Enum.empty?(expanded_ids),
        do: %{},
        else: %{expanded: MapSet.to_list(expanded_ids)}

    {:noreply, push_patch(socket, to: ~p"/user/events?#{params}")}
  end

  def handle_info({:registrations, _operation, _event, attendee}, socket) do
    if attendee.user_id == socket.assigns.current_user.id do
      {:noreply, socket |> assign_events()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket) do
    {:noreply, socket |> assign_events()}
  end

  defp assign_events(socket) do
    user_id = socket.assigns.current_user.id
    events = Events.list_registered_events_for_user(user_id)

    tz = Application.get_env(:dev_round, :time_zone)
    {:ok, now} = DateTime.now(tz)

    underway =
      Enum.filter(events, fn e ->
        begin_local = e.begin |> DateTime.shift_zone!(tz)
        end_local = e.end |> DateTime.shift_zone!(tz)

        archival_datetime =
          end_local
          |> DateTime.to_date()
          |> Date.add(1)
          |> DateTime.new!(~T[00:00:00], tz)

        DateTime.compare(now, begin_local) in [:gt, :eq] and
          DateTime.compare(now, archival_datetime) == :lt
      end)

    upcoming =
      Enum.filter(events, fn e ->
        begin_local = e.begin |> DateTime.shift_zone!(tz)
        DateTime.compare(begin_local, now) == :gt
      end)

    archived =
      Enum.filter(events, fn e ->
        end_local = e.end |> DateTime.shift_zone!(tz)

        archival_datetime =
          end_local
          |> DateTime.to_date()
          |> Date.add(1)
          |> DateTime.new!(~T[00:00:00], tz)

        DateTime.compare(now, archival_datetime) in [:gt, :eq]
      end)

    # Fetch teams for underway sessions + expanded archived sessions
    expanded_ids = socket.assigns[:expanded_ids] || MapSet.new()

    session_ids =
      Enum.flat_map(underway, & &1.sessions)
      |> Enum.concat(
        Enum.filter(archived, &MapSet.member?(expanded_ids, &1.id))
        |> Enum.flat_map(& &1.sessions)
      )
      |> Enum.filter(fn session -> session.teams_locked end)
      |> Enum.map(& &1.id)

    teams_map = DevRound.Hosting.list_teams_for_user_in_sessions(user_id, session_ids)

    socket
    |> assign(:underway_events, underway)
    |> assign(:upcoming_events, upcoming)
    |> assign(:archived_events, archived)
    |> assign(:teams_map, teams_map)
  end

  defp schedule_midnight_check do
    tz = Application.get_env(:dev_round, :time_zone)
    {:ok, now} = DateTime.now(tz)

    next_midnight =
      now
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:01], tz)

    diff_ms = DateTime.diff(next_midnight, now, :millisecond)
    Process.send_after(self(), :refresh_events, diff_ms)
  end
end
