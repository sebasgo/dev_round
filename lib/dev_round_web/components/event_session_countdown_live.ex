defmodule DevRoundWeb.EventSessionCountdownLive do
  use DevRoundWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{event_session: event_session, class: _, style: _} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_time_remaining(event_session)

    # Schedule tick aligned to wallclock seconds if live
    if event_session.live and connected?(socket) do
      schedule_next_tick(event_session.id)
    end

    {:ok, socket}
  end

  def update(%{tick: true}, socket) do
    event_session = socket.assigns.event_session

    if event_session.live and connected?(socket) do
      schedule_next_tick(event_session.id)
    end

    {:ok, socket |> assign_time_remaining(event_session)}
  end

  defp schedule_next_tick(session_id) do
    now = DateTime.utc_now()
    # Calculate milliseconds until next full second
    ms_until_next_second = 1000 - (now.microsecond |> elem(0) |> div(1000))

    Process.send_after(self(), {:tick, session_id}, ms_until_next_second)
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["pt-[2px]", @class]} style={@style}>
      <%= if @time_remaining do %>
        <div class="countdown">
          <%= if @time_remaining.day_digits > 0 do %>
            <span style={"--value:#{@time_remaining.days}; --digits: #{@time_remaining.day_digits};"}></span>:
          <% end %>
          <span style={"--value:#{@time_remaining.hours}; --digits: 2"}></span>: <span style={"--value:#{@time_remaining.minutes}; --digits: 2"}></span>:
          <span style={"--value:#{@time_remaining.seconds}; --digits: 2"}></span>
        </div>
      <% else %>
        <span class="text-error animate-pulse">Session Ended</span>
      <% end %>
    </div>
    """
  end

  defp assign_time_remaining(socket, event_session) do
    if event_session.live do
      case calculate_time_remaining(event_session.actual_begin, event_session.end) do
        {:ok, time_remaining} ->
          assign(socket, :time_remaining, time_remaining)

        {:expired, _} ->
          assign(socket, :time_remaining, nil)
      end
    else
      assign(socket, :time_remaining, nil)
    end
  end

  defp calculate_time_remaining(begin_datetime, end_datetime) do
    now = DateTime.utc_now()

    case DateTime.compare(end_datetime, now) do
      :gt ->
        diff = DateTime.diff(end_datetime, now, :second)

        days = div(diff, 86_400)
        hours = div(rem(diff, 86_400), 3600)
        minutes = div(rem(diff, 3600), 60)
        seconds = rem(diff, 60)

        total_days = DateTime.diff(end_datetime, begin_datetime, :day)

        day_digits =
          case total_days do
            0 -> 0
            _ -> total_days |> Integer.to_string() |> String.length()
          end

        {:ok,
         %{days: days, hours: hours, minutes: minutes, seconds: seconds, day_digits: day_digits}}

      _ ->
        {:expired, %{days: 0, hours: 0, minutes: 0, seconds: 0, day_digits: 0}}
    end
  end

  defmacro __using__(:relay_countdown_ticks) do
    quote do
      def handle_info({:tick, session_id}, socket) do
        send_update(DevRoundWeb.EventSessionCountdownLive,
          id: "countdown-#{session_id}",
          tick: true
        )

        {:noreply, socket}
      end
    end
  end
end
