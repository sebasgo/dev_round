defmodule DevRound.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Changeset
  alias DevRound.Events.Lang
  alias DevRound.Events.EventAttendee
  alias DevRound.Events.EventSession
  alias DevRound.Accounts.User

  schema "events" do
    field :title, :string
    field :location, :string
    field :begin, :utc_datetime
    field :begin_local, :naive_datetime
    field :end, :utc_datetime
    field :end_local, :naive_datetime
    field :teaser, :string, default: ""
    field :body, :string
    field :published, :boolean, default: false
    field :registration_deadline, :utc_datetime
    field :registration_deadline_local, :naive_datetime
    field :slug, :string

    many_to_many :langs, Lang, join_through: "event_langs", on_replace: :delete
    many_to_many :hosts, User, join_through: "event_hosts", on_replace: :delete
    has_many :events_attendees, EventAttendee, on_replace: :delete, on_delete: :delete_all
    has_many :attendees, through: [:events_attendees, :user]
    has_many :sessions, EventSession, on_replace: :delete, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, _opts \\ %{}) do
    event
    |> cast(attrs, [
      :title,
      :teaser,
      :body,
      :begin_local,
      :end_local,
      :location,
      :published,
      :registration_deadline_local
    ])
    |> cast_assoc(:sessions,
      with: &EventSession.changeset/2,
      required: true,
      required_message: "At least one session is required.",
      sort_param: :sessions_order,
      drop_param: :sessions_delete
    )
    |> validate_required(
      [
        :title,
        :teaser,
        :body,
        :begin_local,
        :end_local,
        :location,
        :published,
        :registration_deadline_local
      ],
      message: "Required."
    )
    |> fill_utc_dates(
      begin_local: :begin,
      end_local: :end,
      registration_deadline_local: :registration_deadline
    )
    |> validate_begin_before_end()
    |> validate_registration_deadline_before_begin()
    |> validate_sessions_within_event_dates()
    |> validate_option_selected([:langs, :hosts])
    |> generate_date_title_slug()
    |> unique_constraint(:slug)
  end

  defp validate_registration_deadline_before_begin(changeset) do
    registration_deadline = get_field(changeset, :registration_deadline)
    begin = get_field(changeset, :begin)

    if registration_deadline != nil && begin != nil &&
         DateTime.compare(registration_deadline, begin) != :lt do
      add_error(changeset, :registration_deadline_local, "Must be before begin.")
    else
      changeset
    end
  end

  defp validate_sessions_within_event_dates(changeset) do
    sessions = get_field(changeset, :sessions)
    begin = get_field(changeset, :begin)
    end_ = get_field(changeset, :end)

    changeset =
      if sessions != nil && begin != nil && end_ != nil do
        Enum.reduce(sessions, changeset, &validate_session_with_event_dates/2)
      else
        changeset
      end

    changeset
  end

  defp validate_session_with_event_dates(session, changeset) do
    event_begin = get_field(changeset, :begin)
    event_end = get_field(changeset, :end)
    begin = session.begin
    end_ = Map.fetch!(session, :end)

    changeset =
      if begin != nil && DateTime.compare(event_begin, begin) == :gt do
        add_error(
          changeset,
          :sessions,
          "#{EventSession.title(session)} must begin after or with event."
        )
      else
        changeset
      end

    changeset =
      if end_ != nil && DateTime.compare(event_end, end_) == :lt do
        add_error(
          changeset,
          :sessions,
          "#{EventSession.title(session)} must end before or with event."
        )
      else
        changeset
      end

    changeset
  end

  defimpl Phoenix.Param, for: DevRound.Events.Event do
    def to_param(%{slug: slug}), do: slug
  end
end
