defmodule DevRoundWeb.EventComponents do
  @moduledoc """
  Components for event-related UI elements.

  Provides reusable UI components for displaying event information,
  team structures, and attendee details.
  """

  use Phoenix.Component
  use DevRoundWeb, :verified_routes
  alias DevRound.Hosting.Team

  attr :team, Team, required: true
  attr :show_attendee_experience_level, :boolean, required: true
  attr :show_attendee_langs, :boolean, required: true
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
          <%= for item <- Enum.intersperse(@team.attendees, :divider) do %>
            <%= case item do %>
              <% :divider -> %>
                <div class="mx-1px border-t border-neutral" />
              <% attendee -> %>
                <div class="">
                  <DevRoundWeb.AvatarComponents.user_badge
                    user={attendee.user}
                    remote={attendee.is_remote}
                    experience_level={
                      (@show_attendee_experience_level && attendee.experience_level) || nil
                    }
                  >
                    <p :if={@show_attendee_langs and @multiple_langs} class="text-sm">
                      {Enum.map(attendee.langs, fn lang -> lang.name end)
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
end
