defmodule DevRoundWeb.Admin.ItemActions.ViewEventAction do
  @moduledoc """
  Backpex item action that opens the public event page.

  Renders as a link to the event's main page (`/events/:slug`) and is available
  to admins and hosts. It replaces the built-in show action, which points at the
  admin-only show view.
  """

  use BackpexWeb, :item_action

  use DevRoundWeb, :verified_routes

  @impl Backpex.ItemAction
  def icon(assigns, _item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon
      name="hero-eye"
      class="h-5 w-5 cursor-pointer transition duration-75 hover:text-success hover:scale-110"
    />
    """
  end

  @impl Backpex.ItemAction
  def label(assigns, _item), do: Backpex.__("View", assigns.live_resource)

  @impl Backpex.ItemAction
  def link(_assigns, item), do: ~p"/events/#{item}"
end
