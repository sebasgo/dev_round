defmodule DevRoundWeb.Admin.UserToken do
  @moduledoc """
  Admin panel for user tokens.

  Allows to see and delete active user sessions.
  """

  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Accounts.UserToken,
      repo: DevRound.Repo,
      item_query: &__MODULE__.item_query/3
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    init_order: %{by: :inserted_at, direction: :desc},
    pubsub: [
      topic: "admin.user_tokens"
    ]

  import Ecto.Query, warn: false

  def item_query(query, _live_action, _assigns) do
    query |> where([user_token], user_token.context == "session")
  end

  @impl Backpex.LiveResource
  def singular_name, do: "User Session"

  @impl Backpex.LiveResource
  def plural_name, do: "User Sessions"

  @impl Backpex.LiveResource
  def fields do
    [
      user: %{
        module: Backpex.Fields.BelongsTo,
        label: "User",
        display_field: :full_name,
        live_resource: DevRoundWeb.Admin.User
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Creation Date",
        format: &DevRound.Formats.format_datetime/1
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions([_show, _edit, delete]) do
    [delete]
  end

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item) when action in [:index, :delete], do: true
  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def filters,
    do: [
      user_id: %{
        module: DevRoundWeb.Admin.Filters.UserTokenUserSelect
      }
    ]
end
