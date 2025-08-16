defmodule DevRoundWeb.HostingComponents do
  use Phoenix.Component
  use DevRoundWeb, :verified_routes
  alias Backpex.HTML.CoreComponents
  alias DevRound.Events.Event
  alias DevRound.Events.EventSession

  attr :event, Event, required: true
  attr :session, EventSession, required: false, default: nil

  def header(assigns) do
    ~H"""
    <.breadcrumbs event={@event} />
    <DevRoundWeb.CoreComponents.header>
      Hosting
    </DevRoundWeb.CoreComponents.header>
    <.tabs event={@event} session={@session} />
    """
  end

  attr :event, Event, required: true

  defp breadcrumbs(assigns) do
    ~H"""
    <div class="breadcrumbs">
      <ul>
        <li><.link patch={~p"/events"}>Events</.link></li>
        <li><.link patch={~p"/events/#{@event}"}>{@event.title}</.link></li>
      </ul>
    </div>
    """
  end

  attr :event, Event, required: true
  attr :session, EventSession, required: false, default: nil

  defp tabs(assigns) do
    ~H"""
    <div role="tablist" class="tabs tabs-boxed tabs mt-8">
      <.link
        patch={~p"/events/#{@event}/hosting/lobby"}
        role="tab"
        class={["tab", @session == nil && "tab-active"]}
      >
        Lobby
      </.link>
      <%= for session <- @event.sessions  do %>
        <.link
          patch={~p"/events/#{@event}/hosting/session/#{session}"}
          role="tab"
          class={["tab", @session != nil && @session.id == session.id && "tab-active"]}
        >
          {session.title}
        </.link>
      <% end %>
    </div>
    """
  end

  attr :messages, :list

  def messages(assigns) do
    ~H"""
    <ul :if={not Enum.empty?(@messages)} class="my-8">
      <%= for msg <- @messages do %>
        <li class="flex gap-2 items-center text-error">
          <CoreComponents.icon name="hero-exclamation-circle-mini" class="w-5 h-5" />
          {msg}
        </li>
      <% end %>
    </ul>
    """
  end
end
