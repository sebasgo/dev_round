defmodule DevRoundWeb.HostingLobbyLive.Show do
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase

  alias DevRound.Events.Event
  alias DevRound.Hosting

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("events")
    DevRoundWeb.Endpoint.subscribe("registrations")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug} = params, _, socket) do
    socket =
      socket
      |> assign(:slug, slug)
      |> assign(:registration_edit_username, params["user_name"])
      |> update_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("checkin", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:event, update_attendee_confirmation(socket.assigns.event, id, true))
     |> assign_messages()}
  end

  @impl true
  def handle_event("checkout", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:event, update_attendee_confirmation(socket.assigns.event, id, false))
     |> assign_messages()}
  end

  @impl Phoenix.LiveView
  def handle_info({"event_updated", event}, socket) do
    if event.id == socket.assigns.event.id do
      if event.slug != socket.assigns.event.slug do
        {:noreply, push_patch(socket, to: ~p"/events/#{event}/hosting/lobby")}
      else
        {:noreply, update_assigns(socket)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: "registrations", payload: {_op, event, _attendee}}, socket) do
    if event.id == socket.assigns.event.id do
      {:noreply, update_assigns(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign_messages()
    |> maybe_assign_edit_attendee()
  end

  defp assign_messages(socket) do
    {_, messages} =
      Hosting.validate_team_generation_constraints(
        socket.assigns.event.events_attendees,
        socket.assigns.team_names
      )

    assign(socket, :messages, messages)
  end

  defp maybe_assign_edit_attendee(socket) do
    name = socket.assigns.registration_edit_username

    attendee =
      case socket.assigns.live_action do
        :edit_registration ->
          Enum.find(socket.assigns.event.events_attendees, fn a -> a.user.name == name end)

        _ ->
          nil
      end

    assign(socket, :registration_edit_attendee, attendee)
  end

  defp update_attendee_confirmation(%Event{} = event, id, checked) do
    attendees =
      Enum.map(event.events_attendees, fn attendee ->
        case(attendee.id) do
          ^id ->
            {:ok, attendee} = Hosting.update_event_attendee_checked(attendee, checked)

            broadcast_registration(
              "registration",
              {(checked && :checkin) || :checkout, event, attendee}
            )

            attendee

          _ ->
            attendee
        end
      end)

    %{event | events_attendees: attendees}
  end

  defp broadcast_registration(event, payload) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "registrations", event, payload)
  end

  defp page_title(:show), do: "Hosting Lobby"
  defp page_title(:edit_registration), do: "Hosting Lobby · Edit Registration"
end
