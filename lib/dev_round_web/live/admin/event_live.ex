defmodule DevRoundWeb.Admin.EventLive do
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
      create_changeset: &DevRound.Events.Event.changeset/3,
      item_query: &__MODULE__.item_query/3
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
  def can?(%{current_user: %{role: :admin}}, _action, _item), do: true

  def can?(%{current_user: %{}}, action, _item) when action in [:index, :edit], do: true

  def can?(_assigns, _action, _item), do: false

  @doc """
  Scopes event queries to the events hosted by the current user.

  Admins can access all events, while hosts only see (and can only edit)
  the events they host. Used by Backpex on the index, edit and show views.
  """
  def item_query(query, _live_action, %{current_user: %{role: :admin}}), do: query

  def item_query(query, _live_action, %{current_user: %{id: user_id}}) do
    from e in query,
      join: eh in assoc(e, :event_hosts),
      where: eh.user_id == ^user_id
  end

  def item_query(query, _live_action, _assigns), do: from(e in query, where: false)

  defp admin?(%{current_user: %{role: :admin}}), do: true
  defp admin?(_assigns), do: false

  defp readonly_for_hosts(assigns), do: not admin?(assigns)

  # HasMany has no built-in `readonly` support, so render the selected
  # programming languages as read-only badges for hosts.
  defp langs_form(assigns) do
    if admin?(assigns) do
      Backpex.Fields.HasMany.render_form(assigns)
    else
      assigns = assign(assigns, :host_langs, Map.get(assigns.item, :langs, []))

      ~H"""
      <div>
        <Backpex.HTML.Layout.field_container>
          <:label align={Backpex.Field.align_label(@field_options, assigns, :top)}>
            <Backpex.HTML.Layout.input_label as="span" text={@field_options[:label]} />
          </:label>
          <div class="flex flex-wrap gap-1">
            <span :for={lang <- @host_langs} class="badge badge-sm badge-soft badge-primary">
              {lang.name}
            </span>
          </div>
        </Backpex.HTML.Layout.field_container>
      </div>
      """
    end
  end

  # Boolean has no `readonly` support in its form, so render the flag as a
  # read-only icon for hosts.
  defp boolean_form(assigns) do
    if admin?(assigns) do
      Backpex.Fields.Boolean.render_form(assigns)
    else
      assigns = assign(assigns, :host_value, Map.get(assigns.item, assigns.name, false))

      ~H"""
      <div>
        <Backpex.HTML.Layout.field_container>
          <:label align={Backpex.Field.align_label(@field_options, assigns, :top)}>
            <Backpex.HTML.Layout.input_label as="span" text={@field_options[:label]} />
          </:label>
          <div>
            <Backpex.HTML.CoreComponents.icon
              :if={@host_value}
              name="hero-check-solid"
              class="text-success h-5 w-5"
            />
            <Backpex.HTML.CoreComponents.icon
              :if={!@host_value}
              name="hero-x-mark-solid"
              class="text-error h-5 w-5"
            />
          </div>
        </Backpex.HTML.Layout.field_container>
      </div>
      """
    end
  end

  # URL has no `readonly` support in its form, so render the value as a
  # read-only link for hosts.
  defp url_form(assigns) do
    if admin?(assigns) do
      Backpex.Fields.URL.render_form(assigns)
    else
      assigns = assign(assigns, :value, Map.get(assigns.item, assigns.name))

      ~H"""
      <div>
        <Backpex.HTML.Layout.field_container>
          <:label align={Backpex.Field.align_label(@field_options, assigns, :top)}>
            <Backpex.HTML.Layout.input_label as="span" text={@field_options[:label]} />
          </:label>
          <%= if @value in [nil, ""] do %>
            <p class="opacity-70">—</p>
          <% else %>
            {Backpex.Fields.URL.render_value(assigns)}
          <% end %>
        </Backpex.HTML.Layout.field_container>
      </div>
      """
    end
  end

  @impl Backpex.LiveResource
  def on_item_updated(socket, %DevRound.Events.Event{allow_remote_participation: false} = event) do
    event = DevRound.Repo.preload(event, [:hosts, :credited_hosts])
    affected = DevRound.Events.convert_remote_attendees_to_local(event)

    Enum.each(affected, fn user ->
      DevRoundWeb.UserMail.attendance_changed_to_in_person(user, event)
      |> DevRound.Mailer.deliver()
    end)

    socket
  end

  @impl Backpex.LiveResource
  def on_item_updated(socket, _item), do: socket

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
        label: "Title",
        readonly: &readonly_for_hosts/1
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
            live_resource: DevRoundWeb.Admin.UserLive,
            prompt: "Select user",
            options_query: fn query, _field -> query |> order_by(asc: :full_name) end
          },
          credited: %{
            module: Backpex.Fields.Boolean,
            label: "Credited"
          }
        ],
        help_text:
          "All hosts can use the event hosting functions. Only credited hosts are displayed on event pages in the byline.",
        readonly: &readonly_for_hosts/1,
        except: [:index]
      },
      begin_local: %{
        module: Backpex.Fields.DateTime,
        label: "Begin",
        readonly: &readonly_for_hosts/1
      },
      end_local: %{
        module: Backpex.Fields.DateTime,
        label: "End",
        readonly: &readonly_for_hosts/1,
        except: [:index]
      },
      registration_deadline_local: %{
        module: Backpex.Fields.DateTime,
        label: "Registration Deadline",
        help_text: "After this date, all registrations are locked.",
        readonly: &readonly_for_hosts/1,
        except: [:index]
      },
      location: %{
        module: Backpex.Fields.Text,
        label: "Location",
        readonly: &readonly_for_hosts/1,
        except: [:index]
      },
      langs: %{
        module: Backpex.Fields.HasMany,
        label: "Programming Languages",
        display_field: :name,
        live_resource: DevRoundWeb.Admin.LangLive,
        prompt: "Select",
        not_found_text: "No languages found",
        render_form: &langs_form/1,
        panel: :content,
        except: [:index]
      },
      teaser: %{
        module: Backpex.Fields.Textarea,
        label: "Teaser",
        help_text: "Displayed in event listings. Markdown is supported.",
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
        render_form: &url_form/1,
        panel: :video_conference_rooms,
        except: [:index]
      },
      team_video_conference_rooms: %{
        module: DevRoundWeb.Admin.Fields.InlineCRUD,
        type: :assoc,
        label: "Team Video Conference Rooms",
        child_fields: [
          url: %{
            module: Backpex.Fields.URL,
            label: "URL"
          }
        ],
        help_text: "Used for teams with remote attendees.",
        readonly: &readonly_for_hosts/1,
        panel: :video_conference_rooms,
        except: [:index]
      },
      published: %{
        module: Backpex.Fields.Boolean,
        label: "Published",
        render_form: &boolean_form/1,
        panel: :settings
      },
      allow_remote_participation: %{
        module: Backpex.Fields.Boolean,
        label: "Remote Participation",
        help_text: "Allow attendees to register for remote participation.",
        render_form: &boolean_form/1,
        panel: :settings,
        except: [:index]
      }
    ]
  end
end
