defmodule DevRoundWeb.Admin.Event do
  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.Event,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.Event.changeset/3,
      create_changeset: &DevRound.Events.Event.changeset/3,
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      name: DevRound.PubSub,
      topic: "events",
      event_prefix: "event_"
    ],
    init_order: %{by: :begin, direction: :desc}

  @impl Backpex.LiveResource
  def singular_name, do: "Event"

  @impl Backpex.LiveResource
  def plural_name, do: "Events"

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
      },
      begin_local: %{
        module: Backpex.Fields.DateTime,
        label: "Begin",
      },
      end_local: %{
        module: Backpex.Fields.DateTime,
        label: "End",
      },
      location: %{
        module: Backpex.Fields.Text,
        label: "Location",
        except: [:index]
      },
      langs: %{
        module: Backpex.Fields.HasMany,
        label: "Programming Languages",
        display_field: :name,
        live_resource: DevRoundWeb.Admin.EventLangAdmin,
        prompt: "Select",
        not_found_text: "No languages found",
        except: [:index]
      },
      hosts: %{
        module: Backpex.Fields.HasMany,
        label: "Hosts",
        display_field: :full_name,
        live_resource: DevRoundWeb.Admin.User,
        prompt: "Select users",
        not_found_text: "No users found",
        except: [:index]
      },
      teaser: %{
        module: Backpex.Fields.Textarea,
        label: "Teaser",
        rows: 5,
        except: [:index]
      },
      body: %{
        module: Backpex.Fields.Textarea,
        label: "Body",
        rows: 15,
        except: [:index]
      },
      attendees: %{
        module: Backpex.Fields.HasManyThrough,
        label: "Attendees",
        display_field: :full_name,
        live_resource: DevRoundWeb.Admin.User,
        # prompt: "Select users",
        # not_found_text: "No users found",
        pivot_fields: [
          is_remote: %{
            module: Backpex.Fields.Boolean,
            label: "Remote Attendence",
          },
          expierence_level: %{
            module: Backpex.Fields.Number,
            label: "Expierence Level"
          }
        ],
        child_fields: [
          full_name: %{
            module: Backpex.Fields.Text, label: "Full name"
          }],
        except: [:index]
      },
      published: %{
        module: Backpex.Fields.Boolean,
        label: "Published"
      },
      registration_deadline_local: %{
        module: Backpex.Fields.DateTime,
        label: "Registration Deadline",
      },
    ]
  end

end
