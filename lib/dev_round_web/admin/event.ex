defmodule DevRoundWeb.Admin.Event do
  use DevRoundWeb.Admin.Upload, upload_dir: DevRound.Events.event_slides_dir(), field: :slides_filename
  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.Event,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.Event.changeset/3,
      create_changeset: &DevRound.Events.Event.changeset/3
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      topic: "admin.events"
    ],
    init_order: %{by: :begin, direction: :desc},
    save_and_continue_button?: true

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
          module: DevRoundWeb.Admin.ItemActions.DuplicateEvent,
          only: [:row]
        }
      ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
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
        help_text: "Shown on event listing page.",
        rows: 5,
        except: [:index]
      },
      body: %{
        module: Backpex.Fields.Textarea,
        label: "Body",
        help_text: "Markdown ist supported.",
        rows: 15,
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
              <Phoenix.Component.link navigate={file_url(@value)}>
                {Backpex.HTML.pretty_value(@value)}
              </Phoenix.Component.link>
            </p>
            """
        end
      },
      sessions: %{
        module: DevRoundWeb.Admin.Fields.Sessions,
        type: :assoc,
        label: "Sessions",
        except: [:index],
        child_fields: [
          title: %{
            module: Backpex.Fields.Text,
            label: "Title",
            input_type: :text
          },
          begin_local: %{
            module: Backpex.Fields.DateTime,
            label: "Begin",
            input_type: :date_time
          },
          end_local: %{
            module: Backpex.Fields.DateTime,
            label: "End",
            input_type: :date_time
          }
        ]
      },
      published: %{
        module: Backpex.Fields.Boolean,
        label: "Published"
      }
    ]
  end
end
