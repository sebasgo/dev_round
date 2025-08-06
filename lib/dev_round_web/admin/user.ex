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
      name: DevRound.PubSub,
      topic: "event_langs",
      event_prefix: "event_lang_"
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
      experience_level: %{
        module: Backpex.Fields.Number,
        label: "Experience Level"
      },
      avatar_url: %{
        module: Backpex.Fields.Text,
        label: "Avatar URL"
      }
    ]
  end
end
