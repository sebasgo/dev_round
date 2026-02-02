defmodule DevRoundWeb.AvatarComponents do
  use Phoenix.Component
  use DevRoundWeb, :verified_routes
  import DevRoundWeb.CoreComponents

  @doc """
  Renders a user badge.
  """
  attr :user, DevRound.Accounts.User, required: true
  attr :remote, :boolean, default: false
  attr :experience_level, :integer, default: nil
  slot :inner_block

  def user_badge(assigns) do
    ~H"""
    <div class="flex items-center bg-neutral-content text-neutral rounded-full border border-neutral-content whitespace-nowrap">
      <div class="relative w-10 h-10">
        <.user_avatar user={@user} />
        <%= if @remote do %>
          <div class="absolute top-0 right-0 w-4 h-4 bg-white rounded-full flex">
            <.icon name="hero-globe-alt" class="w-4 h-4" />
          </div>
        <% end %>
        <%= if @experience_level != nil do %>
          <div class="absolute bottom-0 right-0 w-4 h-4 bg-primary rounded-full flex content-center justify-center text-xs">
            {@experience_level}
          </div>
        <% end %>
      </div>
      <div class="ml-2 mr-4">
        {@user.full_name}
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a user avatar.
  """
  attr :user, DevRound.Accounts.User, required: true
  attr :class, :string, default: nil

  def user_avatar(%{user: %DevRound.Accounts.User{avatar: nil}} = assigns) do
    ~H"""
    <div class={["avatar avatar-placeholder", @class]}>
      <div class="bg-neutral text-neutral-content w-10 rounded-full">
        <span>{DevRound.Formats.format_avatar_placeholder(@user)}</span>
      </div>
    </div>
    """
  end

  def user_avatar(assigns) do
    ~H"""
    <div class={["avatar", @class]}>
      <div class="w-10 rounded-full">
        <img class="inline" src={~p"/avatar/#{@user}/#{Base.url_encode64(@user.avatar_hash)}"} alt="" />
      </div>
    </div>
    """
  end
end
