defmodule DevRoundWeb.Breadcrumbs do
  use Phoenix.Component
  use DevRoundWeb, :verified_routes

  attr :items, :list, required: true

  def breadcrumbs(assigns) do
    ~H"""
    <div class="breadcrumbs mb-5 text-sm text-base-content/70">
      <ul>
        <.breadcrumb :for={item <- @items} item={item} />
      </ul>
    </div>
    """
  end

  attr :item, :any, required: true

  def breadcrumb(%{item: :events} = assigns) do
    ~H"""
    <li><.link patch={~p"/events"}>Events</.link></li>
    """
  end

  def breadcrumb(%{item: %DevRound.Events.Event{}} = assigns) do
    ~H"""
    <li><.link patch={~p"/events/#{@item}"}>{@item.title}</.link></li>
    """
  end
end
