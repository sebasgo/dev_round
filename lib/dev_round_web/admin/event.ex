defmodule DevRoundWeb.Admin.Event do
  @moduledoc """
  Backpex resource configuration for managing events.

  Provides CRUD operations for events with support for:
  - Event scheduling and session management
  - Language and host associations
  - Slide uploads
  - Markdown body content
  - Registration deadline settings
  """

  use DevRoundWeb.Admin.Upload,
    upload_dir: DevRound.Events.event_slides_dir(),
    field: :slides_filename

  use DevRoundWeb, :verified_routes

  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.Event,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.Event.changeset/3,
      create_changeset: &DevRound.Events.Event.changeset/3
    ],
    pubsub: [
      topic: "admin.events"
    ],
    init_order: %{by: :begin_local, direction: :desc},
    full_text_search: :searchable_text,
    save_and_continue_button?: true

  import Ecto.Query

  @impl Backpex.LiveResource
  def layout(_assigns), do: {DevRoundWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Event"

  @impl Backpex.LiveResource
  def plural_name, do: "Events"

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def item_actions(actions) do
    actions ++
      [
        duplicate: %{
          module: DevRoundWeb.Admin.ItemActions.DuplicateEventAction,
          only: [:row]
        }
      ]
  end

  @impl Backpex.LiveResource
  def panels do
    [
      content: "Content",
      video_conference_rooms: "Video Conference Rooms",
      settings: "Settings"
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      title: %{
        module: Backpex.Fields.Text,
        label: "Title"
      },
      event_hosts: %{
        module: DevRoundWeb.Admin.Fields.InlineCRUD,
        label: "Hosts",
        type: :assoc,
        child_fields: [
          user: %{
            module: DevRoundWeb.Admin.Fields.BelongsTo,
            label: "User",
            display_field: :full_name,
            live_resource: DevRoundWeb.Admin.User,
            prompt: "Select user",
            options_query: fn query, _field -> query |> order_by(asc: :full_name) end
          }
        ],
        except: [:index]
      },
      begin_local: %{
        module: Backpex.Fields.DateTime,
        label: "Begin"
      },
      end_local: %{
        module: Backpex.Fields.DateTime,
        label: "End",
        except: [:index]
      },
      registration_deadline_local: %{
        module: Backpex.Fields.DateTime,
        label: "Registration Deadline",
        help_text: "After this date, all registrations are locked.",
        except: [:index]
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
        live_resource: DevRoundWeb.Admin.Lang,
        prompt: "Select",
        not_found_text: "No languages found",
        panel: :content,
        except: [:index]
      },
      teaser: %{
        module: Backpex.Fields.Textarea,
        label: "Teaser",
        help_text: "Shown on event listing page.",
        rows: 5,
        panel: :content,
        except: [:index]
      },
      body: %{
        module: Backpex.Fields.Textarea,
        label: "Body",
        help_text: "Markdown is supported.",
        rows: 15,
        panel: :content,
        except: [:index]
      },
      slides_filename: %{
        module: Backpex.Fields.Upload,
        label: "Slides",
        upload_key: :slides,
        accept: ~w(.pdf),
        max_file_size: 50_000_000,
        put_upload_change: &put_upload_change/6,
        consume_upload: &consume_upload/4,
        remove_uploads: &remove_uploads/3,
        list_existing_files: &list_existing_files/1,
        render: fn
          %{value: value} = assigns when value == "" or is_nil(value) ->
            ~H"<p>{Backpex.HTML.pretty_value(@value)}</p>"

          assigns ->
            ~H"""
            <p>
              <Phoenix.Component.link navigate={DevRoundWeb.Urls.event_slides_url(@item, download: true)}>
                {Backpex.HTML.pretty_value(@item.slug)}.pdf
              </Phoenix.Component.link>
            </p>
            """
        end,
        panel: :content,
        except: [:index]
      },
      sessions: %{
        module: Backpex.Fields.InlineCRUD,
        type: :assoc,
        label: "Sessions",
        except: [:index],
        child_fields: [
          title: %{
            module: Backpex.Fields.Text,
            label: "Title"
          },
          begin_local: %{
            module: Backpex.Fields.DateTime,
            label: "Begin"
          },
          end_local: %{
            module: Backpex.Fields.DateTime,
            label: "End"
          }
        ],
        panel: :content
      },
      main_video_conference_room_url: %{
        module: Backpex.Fields.URL,
        label: "Main Video Conference Room URL",
        panel: :video_conference_rooms,
        except: [:index]
      },
      team_video_conference_rooms: %{
        module: Backpex.Fields.InlineCRUD,
        type: :assoc,
        label: "Team Video Conference Rooms",
        child_fields: [
          url: %{
            module: Backpex.Fields.URL,
            label: "URL"
          }
        ],
        help_text: "Used for teams with remote attendees.",
        panel: :video_conference_rooms,
        except: [:index]
      },
      published: %{
        module: Backpex.Fields.Boolean,
        label: "Published",
        panel: :settings
      }
    ]
  end
end
