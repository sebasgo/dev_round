defmodule DevRoundWeb.HostingLobbyLive.Show do
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase

  alias DevRound.Events.Event
  alias DevRound.Hosting

  @order_options [
    {"Registration date", "registration"},
    {"Remote attendance / Name", "is_remote_and_full_name"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
    DevRoundWeb.Endpoint.subscribe("registrations")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug} = params, _, socket) do
    filter = Map.get(params, "filter", "")
    order_param = Map.get(params, "order")

    socket =
      socket
      |> assign(:slug, slug)
      |> assign(:registration_edit_username, params["user_name"])
      |> assign(:filter, filter)
      |> assign(:order_param, order_param)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_change", %{"filter" => filter, "order" => order}, socket) do
    query_params =
      %{}
      |> maybe_put_filter(filter)
      |> maybe_put_order(order)

    path =
      case socket.assigns.live_action do
        :edit_registration ->
          ~p"/events/#{socket.assigns.event}/hosting/lobby/registration/edit/#{socket.assigns.registration_edit_username}?#{query_params}"

        _ ->
          ~p"/events/#{socket.assigns.event}/hosting/lobby?#{query_params}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("checkin", %{"id" => id}, socket) do
    socket =
      socket
      |> assign(:event, update_attendee_confirmation(socket.assigns.event, id, true))
      |> assign_filtered_attendees()
      |> assign_messages()

    {:noreply, socket}
  end

  @impl true
  def handle_event("checkout", %{"id" => id}, socket) do
    socket =
      socket
      |> assign(:event, update_attendee_confirmation(socket.assigns.event, id, false))
      |> assign_filtered_attendees()
      |> assign_messages()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({"updated", %Event{} = event}, socket) do
    if event.id == socket.assigns.event.id do
      if event.slug != socket.assigns.event.slug do
        {:noreply,
         push_patch(socket, to: ~p"/events/#{event}/hosting/lobby?#{socket.assigns.query_params}")}
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
    |> assign_event_with_order()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign_messages()
    |> assign_filtered_attendees()
    |> maybe_assign_edit_attendee()
  end

  defp assign_event_with_order(socket) do
    case parse_order(socket.assigns[:order_param]) do
      nil ->
        socket = assign_event(socket, order_attendees_by: :registration)
        order = default_order(socket.assigns.event)

        socket =
          if order != :registration do
            assign_event(socket, order_attendees_by: order)
          else
            socket
          end

        assign(socket, :order, order)

      order ->
        socket
        |> assign_event(order_attendees_by: order)
        |> assign(:order, order)
    end
  end

  defp parse_order("registration"), do: :registration
  defp parse_order("is_remote_and_full_name"), do: :is_remote_and_full_name
  defp parse_order(_), do: nil

  defp default_order(%Event{begin: begin}) do
    if DateTime.compare(DateTime.utc_now(), begin) != :lt do
      :is_remote_and_full_name
    else
      :registration
    end
  end

  defp assign_filtered_attendees(socket) do
    filter = socket.assigns[:filter] || ""
    order = socket.assigns.order
    attendees = socket.assigns.event.events_attendees

    filtered_attendees = filter_attendees(attendees, filter)

    query_params =
      %{}
      |> maybe_put_filter(filter)
      |> maybe_put_order(to_string(order))

    socket
    |> assign(:order_options, @order_options)
    |> assign(:filter_form, to_form(%{"filter" => filter, "order" => to_string(order)}))
    |> assign(:filtered_attendees, filtered_attendees)
    |> assign(:query_params, query_params)
  end

  defp filter_attendees(attendees, filter) do
    words =
      filter
      |> to_string()
      |> String.trim()
      |> String.split(~r/\s+/, trim: true)

    case words do
      [] ->
        attendees

      words ->
        Enum.filter(attendees, fn attendee ->
          full_name = String.downcase((attendee.user && attendee.user.full_name) || "")

          Enum.all?(words, fn word ->
            String.contains?(full_name, String.downcase(word))
          end)
        end)
    end
  end

  defp maybe_put_filter(params, filter) do
    if filter && String.trim(filter) != "" do
      Map.put(params, "filter", filter)
    else
      params
    end
  end

  defp maybe_put_order(params, order) do
    if order && order != "" do
      Map.put(params, "order", order)
    else
      params
    end
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
