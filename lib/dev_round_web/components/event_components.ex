defmodule DevRoundWeb.EventComponents do
  @moduledoc """
  Components for event-related UI elements.

  Provides reusable UI components for displaying event information,
  team structures, and attendee details.
  """

  use Phoenix.Component
  use DevRoundWeb, :verified_routes
  import DevRoundWeb.CoreComponents
  alias DevRound.Events.EventSession
  alias DevRound.Hosting.Team

  attr :events, :list, required: true
  attr :title, :string, required: true
  attr :accent_class, :string, required: true
  slot :placeholder

  def event_grid_listing(assigns) do
    ~H"""
    <div class="mb-12">
      <div class="flex items-center gap-3 mb-6">
        <h2 class="text-2xl font-mono font-semibold text-base-content">{@title}</h2>
        <div class={"badge badge-#{@accent_class} badge-lg"}>
          {length(@events)}
        </div>
      </div>

      <%= if @events == [] do %>
        {render_slot(@placeholder)}
      <% else %>
        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <.link
            :for={event <- @events}
            :key={event.id}
            patch={~p"/events/#{event}"}
            class="card card-sm bg-base-300 shadow-md transition-shadow duration-200 border border-base-content/10 hover:border-primary/50"
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
        </div>
      <% end %>
    </div>
    """
  end

  attr :team, Team, required: true
  attr :show_member_experience_level, :boolean, required: true
  attr :show_member_langs, :boolean, required: true
  attr :multiple_langs, :boolean, required: true
  attr :class, :string, default: nil
  attr :zoom, :float, default: nil

  def team(assigns) do
    ~H"""
    <div class={["card bg-base-300", @class]}>
      <div class="card-body p-2 gap-2">
        <h2 class="card-title grid gap-2">
          <span class="flex items-start">
            <span class="grow text-lg font-mono font-semibold text-base-content">
              {@team.name}
            </span>
            <DevRoundWeb.CoreComponents.icon
              :if={@team.is_remote}
              name="hero-globe-alt"
              class="w-6 h-8"
            />
          </span>
          <DevRoundWeb.CoreComponents.lang_badge :if={@multiple_langs} lang={@team.lang} />
        </h2>
        <div
          class="grid gap-0.5 bg-neutral-content border-neutral-content"
          style="border-radius: 24px"
        >
          <%= for item <- Enum.intersperse(@team.members, :divider) do %>
            <%= case item do %>
              <% :divider -> %>
                <div class="mx-1px border-t border-neutral" />
              <% member -> %>
                <div class="">
                  <DevRoundWeb.AvatarComponents.user_badge
                    user={member.user}
                    remote={member.is_remote}
                    experience_level={
                      (@show_member_experience_level && member.experience_level) || nil
                    }
                  >
                    <p :if={@show_member_langs and @multiple_langs} class="text-sm">
                      {Enum.map(member.langs, fn lang -> lang.name end)
                      |> Enum.intersperse(", ")}
                    </p>
                  </DevRoundWeb.AvatarComponents.user_badge>
                </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :session, EventSession, required: true
  attr :class, :string, default: nil

  def session(assigns) do
    ~H"""
    <div class={["card bg-base-300", @class]}>
      <div class="card-body p-2 gap-2">
        <h2 class="card-title flex gap-3 ">
          <span class="grow text-lg font-mono font-semibold text-base-content">
            {@session.title}
          </span>
          <.live_badge :if={@session.live} />
        </h2>
        <div class="card grid lg:grid-cols-2 items-center gap-4">
          <div class="">
            <div class="text-sm text-base-content/70">
              Begin & End
            </div>
            <div class="text-lg font-mono">
              {DevRound.Formats.format_datetime_range_compact(@session.begin, @session.end)}
            </div>
          </div>

          <%= if @session.live do %>
            <div class="">
              <div class="text-sm text-base-content/70">
                Time Remaining
              </div>
              <.live_component
                module={DevRoundWeb.EventSessionCountdownLive}
                id={"countdown-#{@session.id}"}
                event_session={@session}
                class="text-lg font-mono"
                style={nil}
              />
            </div>
          <% end %>
        </div>
        <div class="text-base-content/60"></div>
      </div>
    </div>
    """
  end

  def live_badge(assigns) do
    ~H"""
    <div class="badge badge-info flex items-center gap-2">
      <span class="relative flex h-3 w-3">
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-error opacity-75">
        </span>
        <span class="relative inline-flex rounded-full h-3 w-3 bg-error"></span>
      </span>
      <span class="font-semibold uppercase mt-px">Live</span>
    </div>
    """
  end

  attr :title, :string, required: false
  slot :inner_block

  def content_placeholder(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-sm border border-base-content/10">
      <div class="card-body text-center py-12">
        <div class="mb-4">
          <img src={~p"/images/broken-heart.svg"} class="inline opacity-50 w-[128px]" />
        </div>
        <h3 class="text-xl font-medium text-base-content/50 mb-2">{@title}</h3>
        <p class="text-base-content/50">
          {render_slot(@inner_block)}
        </p>
      </div>
    </div>
    """
  end
end
