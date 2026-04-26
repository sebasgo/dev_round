defmodule DevRoundWeb.Admin.EventAttendeesLive do
  @moduledoc """
  Backpex resource configuration for managing event attendees.

  Provides CRUD operations for event attendee records with
  associations to events, users, and programming languages.
  """

  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.EventAttendee,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.EventAttendee.changeset/3,
      create_changeset: &DevRound.Events.EventAttendee.changeset/3
    ],
    pubsub: [
      topic: "admin.event_attendees"
    ],
    init_order: %{by: :begin, direction: :desc}

  @impl Backpex.LiveResource
  def layout(_assigns), do: {DevRoundWeb.Layouts, :admin}

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
        live_resource: DevRoundWeb.Admin.EventLive,
        prompt: "Select"
      },
      user: %{
        module: Backpex.Fields.BelongsTo,
        label: "User",
        display_field: :full_name,
        live_resource: DevRoundWeb.Admin.UserLive,
        prompt: "Select"
      },
      is_remote: %{
        module: Backpex.Fields.Boolean,
        label: "Remote Attendence"
      },
      experience_level: %{
        module: Backpex.Fields.Number,
        label: "Expierence Level"
      },
      langs: %{
        module: Backpex.Fields.HasMany,
        label: "Programming Languages",
        display_field: :name,
        live_resource: DevRoundWeb.Admin.LangLive,
        prompt: "Select",
        not_found_text: "No languages found"
      }
    ]
  end
end
