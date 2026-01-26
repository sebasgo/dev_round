defmodule DevRoundWeb.Admin.User do
  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Accounts.User,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Accounts.User.admin_changeset/3,
      create_changeset: &DevRound.Accounts.User.admin_changeset/3
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      topic: "admin.event_langs"
    ]

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item) when action in [:new, :show], do: false

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Username",
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
