defmodule DevRoundWeb.UserLoginLive do
  use DevRoundWeb, :live_view

  alias DevRound.Accounts
  alias DevRoundWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-sm">
        <.header class="text-center">
          Log in
        </.header>

        <.simple_form for={@form} id="login_form" phx-update="ignore" phx-submit="login">
          <.input field={@form[:name]} type="text" label="User name" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.button type="submit" class="btn btn-primary btn-block flex gap-2">
              <span class="loading loading-spinner loading-md while-submitting"></span>
              <span class="while-submitting">Logging in...</span>
              <span class="while-not-submitting">Log in <span aria-hidden="true">→</span></span>
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end

  @impl true
  def handle_event("login", %{"user" => user_params}, socket) do
    %{"name" => name, "password" => password} = user_params

    case Accounts.authenticate_user_via_ldap(name, password) do
      {:ok, user} ->
        {:noreply,
         socket
         |> UserAuth.log_in_user_live(user)}

      {:error, reason} when reason in [:invalid_credentials, :user_not_found] ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid user name or password!")}

      {:error, :access_denied} ->
        {:noreply,
         socket
         |> put_flash(:error, "Access to this service is not permitted for your account.")}
    end
  end
end
