defmodule DevRoundWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DevRoundWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, DevRound.Accounts.User, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="px-4 sm:px-6 lg:px-8 bg-base-300">
      <div class="navbar mx-auto max-w-3xl px-0">
        <div class=" flex-1">
          <.link
            class="flex flex-shrink-0 flex-grow space-x-2 text-base-content items-center"
            href={~p"/"}
          >
            <img src={~p"/images/logo.svg"} class="h-8" alt="DevRound" />
          </.link>
        </div>
        <div class="flex-none">
          <ul class="menu menu-horizontal px-1">
            <%= if @current_user do %>
              <li>
                <details>
                  <summary>{@current_user.full_name}</summary>
                  <ul class="bg-base-100 rounded-t-none p-2">
                    <li>
                      <.link href={~p"/users/settings"}>
                        Settings
                      </.link>
                    </li>
                    <li>
                      <.link href={~p"/admin"}>
                        Admin Panel
                      </.link>
                    </li>
                    <%= if Application.get_env(:dev_round, :dev_routes) do %>
                      <li>
                        <.link href={~p"/dev/dashboard"}>
                          Phoenix Dashboard
                        </.link>
                      </li>
                      <li>
                        <.link href={~p"/dev/mailbox"}>
                          Swoosh Mailbox
                        </.link>
                      </li>
                      <li>
                        <.link href={~p"/users/log_out"} method="delete">
                          Log out
                        </.link>
                      </li>
                    <% end %>
                  </ul>
                </details>
              </li>
            <% else %>
              <li>
                <.link href={~p"/users/register"}>
                  Register
                </.link>
              </li>
              <li>
                <.link href={~p"/users/log_in"}>
                  Log in
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
