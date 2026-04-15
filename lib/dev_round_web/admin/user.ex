defmodule DevRoundWeb.Admin.User do
  @moduledoc """
  Backpex resource configuration for managing users.

  Provides CRUD operations for user management with LDAP integration.
  """

  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Accounts.User,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Accounts.User.admin_changeset/3,
      create_changeset: &DevRound.Accounts.User.admin_changeset/3
    ],
    init_order: %{by: :name, direction: :asc},
    pubsub: [
      topic: "admin.event_langs"
    ]

  import Ecto.Query, warn: false

  @impl Backpex.LiveResource
  def layout(_assigns), do: {DevRoundWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item) when action in [:new, :show], do: false
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def item_actions([show, edit, delete]) do
    refresh = {:refresh, %{module: DevRoundWeb.Admin.ItemActions.RefreshUserAction}}

    [show, refresh, edit, delete]
  end

  @impl Backpex.LiveResource
  def resource_actions() do
    [
      add_from_ldap: %{module: DevRoundWeb.Admin.ResourceActions.AddUserAction}
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "User Name",
        readonly: true
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        readonly: true
      },
      full_name: %{
        module: Backpex.Fields.Text,
        label: "Full Name",
        readonly: true
      },
      role: %{
        module: Backpex.Fields.Number,
        label: "Role",
        readonly: true,
        only: [:index, :show],
        render: &render_role/1
      },
      experience_level: %{
        module: Backpex.Fields.Number,
        label: "Experience Level"
      }
    ]
  end

  @impl Backpex.LiveResource
  def metrics do
    [
      registered_users: %{
        module: Backpex.Metrics.Value,
        label: "Registered Users",
        class: "w-48",
        select: dynamic([i], count(i)),
        format: fn value ->
          Integer.to_string(value) <> " Users"
        end
      },
      average_experience_level: %{
        module: Backpex.Metrics.Value,
        label: "Average Experience Level",
        class: "w-48",
        select: dynamic([i], avg(i.experience_level)),
        format: fn value ->
          Decimal.to_string(Decimal.round(value, 1))
        end
      }
    ]
  end

  defp render_role(%{value: :user} = assigns) do
    ~H"""
    <div class="badge badge-sm badge-neutral">
      User
    </div>
    """
  end

  defp render_role(%{value: :admin} = assigns) do
    ~H"""
    <div class="badge badge-sm badge-primary">
      Admin
    </div>
    """
  end
end
