defmodule DevRoundWeb.HostLive.Show do
  use DevRoundWeb, :live_view

  alias DevRound.Events

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("events")
    DevRoundWeb.Endpoint.subscribe("registrations")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    socket = socket
    |> fetch_event(params)
    |> ensure_current_user_is_host!()
    {:noreply, socket}
  end

  defp fetch_event(socket, params) do
    assign(socket, :event, Events.get_event!(params["slug"]))
  end

  defp ensure_current_user_is_host!(socket) do
    user = socket.assigns.current_user
    if !Enum.member?(socket.assigns.event.hosts, user) do
      raise DevRoundWeb.PermissionError, message: "\"#{user.name}\" is not an event host"
    end
    socket
  end
end
