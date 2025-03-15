defmodule DevRoundWeb.Admin.Event do
  use Backpex.LiveResource,
  adapter_config: [
    schema: DevRound.Events.Event,
    repo: DevRound.Repo,
    update_changeset: &DevRound.Events.Event.changeset/3,
    create_changeset: &DevRound.Events.Event.changeset/3
  ],
  layout: {DevRoundWeb.Layouts, :admin},
  pubsub: [
    name: DevRound.PubSub,
    topic: "events",
    event_prefix: "event_"
  ]

  @impl Backpex.LiveResource
  def singular_name, do: "Event"

  @impl Backpex.LiveResource
  def plural_name, do: "Events"

  # @impl Backpex.LiveResource
  # def can?(_assigns, action, _item) when action in [:new, :show], do: false

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
      },
      location: %{
        module: Backpex.Fields.Text,
        label: "Location",
      },
      begin: %{
        module: Backpex.Fields.DateTime,
        label: "Begin",
      },
      end: %{
        module: Backpex.Fields.DateTime,
        label: "End",
      },
      body: %{
        module: Backpex.Fields.Textarea,
        label: "Body"
      },
      published: %{
        module: Backpex.Fields.Boolean,
        label: "Published"
      }
    ]
  end

end
