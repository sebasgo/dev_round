defmodule DevRoundWeb.Admin.TeamName do
  use Backpex.LiveResource,
  adapter_config: [
    schema: DevRound.Hosting.TeamName,
    repo: DevRound.Repo,
    update_changeset: &DevRound.Hosting.TeamName.changeset/3,
    create_changeset: &DevRound.Hosting.TeamName.changeset/3
  ],
  layout: {DevRoundWeb.Layouts, :admin},
  pubsub: [
    name: DevRound.PubSub,
    topic: "team_names",
    event_prefix: "team_name_"
  ]

  @impl Backpex.LiveResource
  def singular_name, do: "Team Name"

  @impl Backpex.LiveResource
  def plural_name, do: "Team Names"

  @impl Backpex.LiveResource
  def can?(_assigns, action, _item) when action in [:show], do: false

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
      },
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        readonly: true,
      },
    ]
  end

end
