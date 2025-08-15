defmodule DevRoundWeb.HostingBase do
  import Phoenix.Component
  alias DevRound.{Events, Hosting}

  def assign_event(socket) do
    assign(
      socket,
      :event,
      Events.get_event!(socket.assigns.slug, order_attendees_by: :is_remote_and_full_name)
    )
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
end
