defmodule DevRoundWeb.Admin.EventLangAdmin do
  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.Lang,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.Lang.changeset/3,
      create_changeset: &DevRound.Events.Lang.changeset/3
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      name: DevRound.PubSub,
      topic: "event_langs",
      event_prefix: "event_lang_"
    ]


  @impl Backpex.LiveResource
  def singular_name, do: "Lang"

  @impl Backpex.LiveResource
  def plural_name, do: "Programming Languages"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name"
      },
      icon_path: %{
        module: Backpex.Fields.Text,
        label: "icon"
      }
    ]
  end
end
