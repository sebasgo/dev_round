defmodule DevRoundWeb.RegistrationComponent do
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
          <.button class="btn-primary" phx-disable-with="Saving...">{@save_label}</.button>
          <%= if @action == :edit_registration  && @mode == :self_registration do %>
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
  def update(%{event: event, attendence: attendence, mode: mode} = assigns, socket) do
    attendence = get_or_create_attendee(attendence)
    changeset = Events.change_event_attendee(attendence, event, %{}, mode)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:attendence, attendence)
     |> assign(:title, title(assigns))
     |> assign(:save_label, save_label(assigns.action))
     |> assign_new(:lang_options, fn -> lang_opts(changeset, event) end)
     |> assign_new(:form, fn -> to_form(changeset) end)}
  end

  @impl true
  def handle_event("validate", %{"event_attendee" => event_attendee_params}, socket) do
    %{attendence: attendence, event: event, mode: mode} = socket.assigns
    changeset = Events.change_event_attendee(attendence, event, event_attendee_params, mode)

    {:noreply,
     assign(socket, %{
       form: to_form(changeset, action: :validate),
       lang_options: lang_opts(changeset, event)
     })}
  end

  def handle_event("save", %{"event_attendee" => event_attendee_params}, socket) do
    save_event_attendee(socket, socket.assigns.action, event_attendee_params)
  end

  def handle_event("delete", _, socket) do
    %{:mode => :self_registration} = socket.assigns

    case Events.delete_event_attendee(socket.assigns.attendence, :self_registration) do
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
    case Events.update_event_attendee(
           socket.assigns.attendence,
           event_attendee_params,
           socket.assigns.mode
         ) do
      {:ok, attendee} ->
        event = socket.assigns.event
        broadcast_registration("registration", {:edit, event, attendee})
        notify_parent({:saved, event})

        {:noreply,
         socket
         |> maybe_put_flash(:info, "Registration updated.", fn ->
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
        UserMail.confirm_registration(socket.assigns.user, event) |> Mailer.deliver()
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

  defp title(%{mode: :host, user: user}), do: "Edit Registration · #{user.full_name}"
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
