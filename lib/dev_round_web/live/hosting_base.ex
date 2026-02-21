defmodule DevRoundWeb.HostingBase do
  @moduledoc """
  Base module for hosting LiveViews.

  Provides common functionality for hosting interfaces including:
  - Event assignment
  - Team name assignment
  - Host permission checking
  - Team generation validation messages
  """

  import Phoenix.Component
  alias DevRound.{Events, Hosting}

  def assign_event(socket) do
    event = Events.get_event!(socket.assigns.slug, order_attendees_by: :is_remote_and_full_name)

    socket
    |> assign(:event, event)
    |> assign(:multiple_langs, Events.event_has_multiple_langs?(event))
  end

  def assign_team_names(socket) do
    assign(socket, :team_names, Hosting.list_team_names())
  end

  def ensure_current_user_is_host!(socket) do
    user = socket.assigns.current_user

    if !Enum.member?(socket.assigns.event.hosts, user) do
      raise DevRoundWeb.PermissionError, message: "\"#{user.name}\" is not an event host"
    end

    socket
  end

  def assign_messages(socket) do
    {_, messages} =
      Hosting.validate_team_generation_constraints(
        socket.assigns.event.events_attendees,
        socket.assigns.team_names
      )

    assign(socket, :messages, messages)
  end
end
