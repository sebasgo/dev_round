defmodule DevRoundWeb.EventLive.RegistrationComponent do
alias DevRound.Events.EventAttendee
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
        <p>Choose whether you want to attend in person or remotely via Skype/Pexip:</p>
        <.input field={@form[:is_remote]} type="checkbox" label="Attend remotely" />
        <%= if Enum.empty?(tl(@lang_options)) do %>
          <.input field={@form[:lang_ids]} type="hidden" multiple={true} value={hd(@lang_options)[:value]} />
        <% else %>
          <p> This event is offered for multiple programming languages. Select the languages you feel comfortable to use during the event:</p>
          <.input field={@form[:lang_ids]} type="langs" multiple={true} options={@lang_options} />
        <% end %>

        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">{@save_label}</.button>
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
  def update(%{event: event, attendence: attendence, current_user: user} = assigns, socket) do
    attendence = get_or_create_attendee(attendence)
    changeset = Events.change_event_attendee(attendence, event, user)
    {:ok,
      socket
      |> assign(assigns)
      |> assign(:attendence, attendence)
      |> assign(:title, title(assigns.action, event))
      |> assign(:save_label, save_label(assigns.action))
      |> assign_new(:lang_options, fn -> lang_opts(changeset, event) end)
      |> assign_new(:form, fn -> to_form(changeset) end)
    }
  end

  @impl true
  def handle_event("validate", %{"event_attendee" => event_attendee_params}, socket) do
    event = socket.assigns.event
    user = socket.assigns.current_user
    changeset = Events.change_event_attendee(socket.assigns.attendence, event, user, event_attendee_params)
    {:noreply, assign(socket, %{form: to_form(changeset, action: :validate), lang_options: lang_opts(changeset, event)})}
  end

  def handle_event("save", %{"event_attendee" => event_attendee_params}, socket) do
    save_event_attendee(socket, socket.assigns.action, event_attendee_params)
  end

  def handle_event("delete", _, socket) do
    case Events.delete_event_attendee(socket.assigns.attendence) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:delete, event, attendee})
        notify_parent({:saved, event})
        {:noreply,
          socket
          |> put_flash(:info, "Registration canceled.")
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
    case Events.update_event_attendee(socket.assigns.attendence, event_attendee_params) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:edit, event, attendee})
        notify_parent({:saved, event})
        {:noreply,
         socket
         |> put_flash(:info, "Registration updated.")
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
    case Events.create_event_attendee(socket.assigns.event, socket.assigns.current_user, event_attendee_params) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:new, event, attendee})
        UserMail.confirm_registration(socket.assigns.current_user, event) |> Mailer.deliver()
        notify_parent({:saved, event})

        {:noreply,
         socket
         |> put_flash(:info, "Registered")
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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})


  defp save_label(:new_registration), do: "Register"
  defp save_label(:edit_registration), do: "Update Registration"

  defp title(:new_registration, event), do: "Register for «#{event.title}»"
  defp title(:edit_registration, event), do: "Manage Registration for «#{event.title}»"


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
end
