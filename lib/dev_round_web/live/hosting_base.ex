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
  alias LiveToast

  def assign_event(socket, opts \\ []) do
    order_attendees_by = Keyword.get(opts, :order_attendees_by, :is_remote_and_full_name)
    event = Events.get_event!(socket.assigns.slug, order_attendees_by: order_attendees_by)

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
        socket.assigns.team_names,
        socket.assigns.event.team_video_conference_rooms
      )

    assign(socket, :messages, messages)
  end

  @doc """
  Emits a toast to the current hosting view describing a registration or
  check-in/check-out action performed by another user. The acting user is
  never notified of their own action.
  """
  def maybe_registration_toast(
        socket,
        %{op: op, event: event, attendee: attendee, acting_user: user}
      ) do
    if event.id == socket.assigns.event.id and user.id != socket.assigns.current_user.id do
      self? = user.id == attendee.user_id
      LiveToast.put_toast(socket, :info, toast_message(op, user, attendee, self?), duration: 5000)
    else
      socket
    end
  end

  defp toast_message(op, user, attendee, self?) do
    case {op, self?} do
      {:new, true} ->
        "#{user.full_name} has registered"

      {:new, false} ->
        "#{user.full_name} registered #{attendee.user.full_name}"

      {:edit, true} ->
        "#{user.full_name} has updated their registration"

      {:edit, false} ->
        "#{user.full_name} updated the registration details for #{attendee.user.full_name}"

      {:delete, true} ->
        "#{user.full_name} has canceled their registration"

      {:delete, false} ->
        "#{user.full_name} canceled the registration for #{attendee.user.full_name}"

      {:checkin, _} ->
        "#{user.full_name} checked in #{attendee.user.full_name}"

      {:checkout, _} ->
        "#{user.full_name} checked out #{attendee.user.full_name}"
    end
  end

  @doc """
  Broadcasts a host action to other hosts' hosting views so they can show a toast.
  """
  def broadcast_host_action(_event, payload) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "host_actions", "host_action", payload)
  end

  @doc """
  Emits a toast to the current hosting view describing a host action (building
  teams, starting/resetting a session, swapping members, etc.) performed by
  another host. The acting host is never notified of their own action.
  """
  def maybe_host_action_toast(socket, %{event_id: event_id} = payload) do
    if event_id == socket.assigns.event.id and
         payload.acting_user.id != socket.assigns.current_user.id do
      LiveToast.put_toast(socket, :info, host_action_message(payload), duration: 5000)
    else
      socket
    end
  end

  defp host_action_message(%{action: :build_teams, session_title: title, acting_user: user}) do
    "#{user.full_name} has built teams for the session \"#{title}\"."
  end

  defp host_action_message(%{action: :start_session, session_title: title, acting_user: user}) do
    "#{user.full_name} has started the session \"#{title}\"."
  end

  defp host_action_message(%{action: :return_to_lecture, session_title: title, acting_user: user}) do
    "#{user.full_name} has returned to the lecture from session \"#{title}\"."
  end

  defp host_action_message(%{action: :reset_session, session_title: title, acting_user: user}) do
    "#{user.full_name} has reset the session \"#{title}\"."
  end

  defp host_action_message(%{
         action: :swap_members,
         session_title: title,
         acting_user: user,
         member_a: member_a,
         member_b: member_b
       }) do
    "#{user.full_name} has swapped #{member_a.full_name} and #{member_b.full_name} in session #{title}."
  end

  defp host_action_message(%{action: :set_presentation, live?: true, acting_user: user}) do
    "#{user.full_name} has started the lecture presentation."
  end

  defp host_action_message(%{action: :set_presentation, live?: false, acting_user: user}) do
    "#{user.full_name} has stopped the lecture presentation."
  end
end
