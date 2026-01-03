defmodule DevRoundWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  alias DevRound.Accounts.User
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
  attr :fluid, :boolean, default: false, doc: "toggles fluid layout"

  slot :sidebar, doc: "content to be displayed in the sidebar"
  slot :inner_block, required: true

  def app(%{sidebar: []} = assigns) do
    ~H"""
    <header class="px-4 sm:px-6 lg:px-8 bg-base-300">
      <div class="navbar mx-auto max-w-3xl px-0">
        <.logo_brand />
        <div :if={@current_user} class="flex-none">
          <.user_dropdown current_user={@current_user} />
        </div>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl">
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  def app(assigns) do
    ~H"""
    <div class="drawer">
      <input id="menu-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content">
        <div class="bg-base-200 fixed inset-0 -z-10 h-full w-full"></div>
        <div class={[
          "menu hidden overflow-y-auto px-2 py-5 md:fixed md:inset-y-0 md:mt-16 md:block md:w-64"
        ]}>
          {render_slot(@sidebar)}
        </div>
        <div class="flex flex-1 flex-col md:pl-64">
          <header class="fixed top-0 z-30 block w-full md:-ml-64 px-4 bg-base-300">
            <div class={["navbar mx-auto px-0"]}>
              <.logo_brand />
              <div :if={@current_user} class="flex-none">
                <.user_dropdown current_user={@current_user} />
              </div>
              <label for="menu-drawer" class="btn btn-square drawer-button btn-ghost md:hidden">
                <.icon name="hero-bars-3-solid" class="h-6" />
              </label>
            </div>
          </header>

          <main class="h-[calc(100vh-4rem)] mt-[4rem]">
            <div class={[" px-4 py-5 sm:px-6 lg:px-8 mx-auto", !@fluid && "max-w-3xl"]}>
              {render_slot(@inner_block)}
            </div>
          </main>

          <.flash_group flash={@flash} />
        </div>
      </div>
      <div class="drawer-side z-40">
        <label for="menu-drawer" class="drawer-overlay"></label>
        <div class="bg-base-100 menu min-h-full w-64 flex-1 flex-col overflow-y-auto px-2 pt-5 pb-4">
          {render_slot(@sidebar)}
        </div>
      </div>
    </div>
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

  defp logo_brand(assigns) do
    ~H"""
    <div class="flex-1 flex">
      <.link class="flex-none" href={~p"/"}>
        <img src={~p"/images/logo.svg"} class="h-8" alt="DevRound" />
      </.link>
    </div>
    """
  end

  attr :current_user, User, required: true

  defp user_dropdown(assigns) do
    ~H"""
    <.dropdown id="topbar-dropdown" class="dropdown-end">
      <:trigger>
        <.user_avatar
          user={@current_user}
          class="border-2 border-neutral-content rounded-full cursor-pointer"
        />
      </:trigger>
      <:menu class="w-52 p-2">
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
      </:menu>
    </.dropdown>
    """
  end
end
