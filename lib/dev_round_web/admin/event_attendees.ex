defmodule DevRoundWeb.Admin.EventAttendees do
  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.EventAttendee,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.EventAttendee.changeset/3,
      create_changeset: &DevRound.Events.EventAttendee.changeset/3,
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      name: DevRound.PubSub,
      topic: "event_attendees",
      event_prefix: "event_attendee_"
    ],
    init_order: %{by: :begin, direction: :desc}

  @impl Backpex.LiveResource
  def singular_name, do: "Event Attendee"

  @impl Backpex.LiveResource
  def plural_name, do: "Event Attendees"

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      event: %{
        module: Backpex.Fields.BelongsTo,
        label: "Event",
        display_field: :title,
        live_resource: DevRoundWeb.Admin.Event,
        prompt: "Select",
      },
      user: %{
        module: Backpex.Fields.BelongsTo,
        label: "User",
        display_field: :full_name,
        live_resource: DevRoundWeb.Admin.User,
        prompt: "Select",
      },
      is_remote: %{
        module: Backpex.Fields.Boolean,
        label: "Remote Attendence",
      },
      expierence_level: %{
        module: Backpex.Fields.Number,
        label: "Expierence Level"
      },
      langs: %{
        module: Backpex.Fields.HasMany,
        label: "Programming Languages",
        display_field: :name,
        live_resource: DevRoundWeb.Admin.EventLangAdmin,
        prompt: "Select",
        not_found_text: "No languages found",
      },
    ]
  end

end
