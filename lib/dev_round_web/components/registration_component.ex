defmodule DevRoundWeb.RegistrationComponent do
  @moduledoc """
  LiveComponent for handling event registration forms.

  Provides functionality for users to register for events, including
  selecting attendance type (remote/in-person), experience level, and
  programming languages.
  """

  alias DevRound.Events.EventAttendee
  alias DevRound.Accounts.User
  use DevRoundWeb, :live_component

  alias DevRound.Events
  alias DevRound.Mailer
  alias DevRoundWeb.UserMail

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>{@title}</.header>

      <.simple_form
        for={@form}
        id="event-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <%= if @mode == :host && @action == :new_registration do %>
          <p>Participant:</p>
          <.input
            field={@form[:user_id]}
            type="select"
            options={@user_options}
            prompt="Select participant..."
          />
        <% end %>
        <%= if @mode == :host do %>
          <p>Experience Level:</p>
          <.input field={@form[:experience_level]} type="experience_level" />
        <% end %>
        <%= case @mode do %>
          <% :self_registration -> %>
            <p>Choose whether you want to attend in person or remotely via Skype/Pexip:</p>
          <% :host -> %>
            <p>Remote Attendance:</p>
        <% end %>
        <.input field={@form[:is_remote]} type="checkbox" label="Attend remotely" />
        <%= if Enum.empty?(tl(@lang_options)) do %>
          <.input
            field={@form[:lang_ids]}
            type="hidden"
            multiple={true}
            value={hd(@lang_options)[:value]}
          />
        <% else %>
          <%= case @mode do %>
            <% :self_registration -> %>
              <p>
                This event is offered for multiple programming languages. Select the languages you feel comfortable to use during the event:
              </p>
            <% :host -> %>
              <p>Programming Languages:</p>
          <% end %>
          <.input field={@form[:lang_ids]} type="langs" multiple={true} options={@lang_options} />
        <% end %>

        <:actions>
          <.button variant="primary" phx-disable-with="Saving...">{@save_label}</.button>
          <%= if @action == :edit_registration do %>
            <.button type="button" phx-click={JS.push("delete", target: @myself)}>
              Cancel Registration
            </.button>
          <% end %>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{event: event, attendance: attendance, mode: mode} = assigns, socket) do
    attendance = get_or_create_attendee(attendance)
    changeset = Events.change_event_attendee(attendance, event, %{}, mode)

    unregistered_users =
      if mode == :host && assigns.action == :new_registration do
        Events.list_unregistered_users(event)
      else
        []
      end

    user_options = Enum.map(unregistered_users, &{&1.full_name, &1.id})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:attendance, attendance)
     |> assign(:unregistered_users, unregistered_users)
     |> assign(:user_options, user_options)
     |> assign(:selected_user_id, nil)
     |> assign(:title, title(assigns))
     |> assign(:save_label, save_label(assigns.action))
     |> assign_new(:lang_options, fn -> lang_opts(changeset, event) end)
     |> assign_new(:form, fn -> to_form(changeset) end)}
  end

  @impl true
  def handle_event("validate", %{"event_attendee" => event_attendee_params}, socket) do
    %{attendance: attendance, event: event, mode: mode} = socket.assigns
    event_attendee_params = maybe_prefill_user_experience(event_attendee_params, socket)
    changeset = Events.change_event_attendee(attendance, event, event_attendee_params, mode)

    {:noreply,
     socket
     |> assign(:selected_user_id, event_attendee_params["user_id"])
     |> assign(%{
       form: to_form(changeset, action: :validate),
       lang_options: lang_opts(changeset, event)
     })}
  end

  def handle_event("save", %{"event_attendee" => event_attendee_params}, socket) do
    save_event_attendee(socket, socket.assigns.action, event_attendee_params)
  end

  def handle_event("delete", _, socket) do
    user = socket.assigns.user || (socket.assigns.attendance && socket.assigns.attendance.user)

    case Events.delete_event_attendee(socket.assigns.attendance, socket.assigns.mode) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:delete, event, attendee})

        flash_msg =
          case socket.assigns.mode do
            :self_registration ->
              "Registration canceled."

            :host ->
              "Registration canceled. Notification sent to #{user.full_name}."
          end

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> push_patch(to: socket.assigns.patch)}

      {:error, :registration_closed} ->
        {:noreply,
         socket
         |> put_flash(:error, "Registration for this event is closed.")
         |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp get_or_create_attendee(%EventAttendee{} = attendee), do: attendee
  defp get_or_create_attendee(nil), do: %EventAttendee{}

  defp save_event_attendee(socket, :edit_registration, event_attendee_params) do
    case Events.update_event_attendee(
           socket.assigns.attendance,
           event_attendee_params,
           socket.assigns.mode
         ) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:edit, event, attendee})

        {:noreply,
         socket
         |> maybe_put_flash(:info, "Registration information updated.", fn ->
           socket.assigns.mode == :self_registration
         end)
         |> push_patch(to: socket.assigns.patch)}

      {:error, :registration_closed} ->
        {:noreply,
         socket
         |> put_flash(:error, "Registration for this event is closed.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_event_attendee(socket, :new_registration, event_attendee_params) do
    case Events.create_event_attendee(
           socket.assigns.event,
           socket.assigns.user,
           event_attendee_params,
           socket.assigns.mode
         ) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:new, event, attendee})
        UserMail.confirm_registration(attendee.user, event) |> Mailer.deliver()

        flash_msg =
          case socket.assigns.mode do
            :self_registration ->
              "Registration successful."

            :host ->
              "Registration successful. Confirmation sent to #{attendee.user.full_name}."
          end

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> push_patch(to: socket.assigns.patch)}

      {:error, :registration_closed} ->
        {:noreply,
         socket
         |> put_flash(:error, "Registration for this event is closed.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp maybe_prefill_user_experience(
         params,
         %{
           assigns: %{
             mode: :host,
             selected_user_id: prev_id,
             unregistered_users: users
           }
         }
       ) do
    user_id = params["user_id"]

    if user_id && user_id != "" && user_id != prev_id do
      prefill_experience_for_user(params, users, user_id)
    else
      params
    end
  end

  defp maybe_prefill_user_experience(params, _socket), do: params

  defp prefill_experience_for_user(params, users, user_id) do
    case Enum.find(users, fn u -> to_string(u.id) == to_string(user_id) end) do
      %User{experience_level: exp} -> Map.put(params, "experience_level", to_string(exp))
      _ -> params
    end
  end

  defp save_label(:new_registration), do: "Register"
  defp save_label(:edit_registration), do: "Update Registration"

  defp title(%{mode: :host, action: :edit_registration, user: %User{} = user}),
    do: "Edit Registration · #{user.full_name}"

  defp title(%{mode: :host, action: :new_registration}), do: "Add participant"
  defp title(%{action: :new_registration, event: event}), do: "Register for «#{event.title}»"

  defp title(%{action: :edit_registration, event: event}),
    do: "Manage Registration for «#{event.title}»"

  defp lang_opts(changeset, event) do
    existing_ids =
      changeset
      |> Ecto.Changeset.get_field(:langs, [])
      |> Enum.map(& &1.id)

    for lang <- event.langs,
        do: [key: lang.name, value: lang.id, lang: lang, selected: lang.id in existing_ids]
  end

  defp broadcast_registration(event, payload) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "registrations", event, payload)
  end

  defp maybe_put_flash(socket, kind, msg, cond_fn) do
    if cond_fn.() do
      socket |> put_flash(kind, msg)
    else
      socket
    end
  end
end
