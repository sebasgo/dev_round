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
    field :slides_filename, :string
    field :slides_page_number, :integer
    field :live, :boolean
    field :modified_at, :utc_datetime

    many_to_many :langs, Lang, join_through: "event_langs", on_replace: :delete
    many_to_many :hosts, User, join_through: "event_hosts", on_replace: :delete
    has_many :events_attendees, EventAttendee, on_replace: :delete, on_delete: :delete_all
    has_many :attendees, through: [:events_attendees, :user]
    has_many :sessions, EventSession, on_replace: :delete, on_delete: :delete_all
    belongs_to :last_live_session, EventSession

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, opts \\ []) do
    event
    |> cast(attrs, [
      :title,
      :teaser,
      :body,
      :begin_local,
      :end_local,
      :location,
      :published,
      :registration_deadline_local,
      :slides_filename
    ])
    |> cast_assoc(:sessions,
      with: &EventSession.changeset/2,
      required: true,
      required_message: "At least one session is required.",
      sort_param: :sessions_order,
      drop_param: :sessions_delete
    )
    |> put_langs_assoc(Keyword.get(opts, :put_langs))
    |> put_hosts_assoc(Keyword.get(opts, :put_hosts))
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
    |> validate_sessions_do_not_overlap()
    |> validate_option_selected([:langs, :hosts])
    |> generate_date_title_slug()
    |> validate_change(:slides_filename, fn :slides_filename, path ->
      case path do
        "too_many_files" -> [slides_filename: "Only one file is allowed."]
        _ -> []
      end
    end)
    |> unique_constraint(:slug)
    |> change(modified_at: DateTime.utc_now(:second))
  end

  def slides_page_number_changeset(event, attrs) do
    event
    |> cast(attrs, [:slides_page_number])
    |> validate_required(:slides_page_number)
  end

  def live_changeset(event, attrs) do
    event
    |> cast(attrs, :live)
    |> validate_required(:live)
  end

  defp put_langs_assoc(changeset, nil = _langs), do: changeset
  defp put_langs_assoc(changeset, langs), do: put_assoc(changeset, :langs, langs)

  defp put_hosts_assoc(changeset, nil = _hosts), do: changeset
  defp put_hosts_assoc(changeset, hosts), do: put_assoc(changeset, :hosts, hosts)

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
        Enum.reduce(sessions, changeset, &validate_session_within_event_dates/2)
      else
        changeset
      end

    changeset
  end

  defp validate_session_within_event_dates(session, changeset) do
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

  defp validate_sessions_do_not_overlap(changeset) do
    sessions = get_field(changeset, :sessions, [])
    validate_sessions_do_not_overlap(changeset, sessions)
  end

  defp validate_sessions_do_not_overlap(changeset, [session | rest]) do
    Enum.reduce(rest, changeset, fn other, changeset ->
      validate_session_does_not_overlap(changeset, session, other)
    end)
  end

  defp validate_sessions_do_not_overlap(changeset, []), do: changeset

  defp validate_session_does_not_overlap(
         changeset,
         %EventSession{} = session,
         %EventSession{} = other
       ) do
    if sessions_overlap?(session, other) do
      add_error(
        changeset,
        :sessions,
        "#{EventSession.title(session)} overlaps with #{EventSession.title(other)}."
      )
    else
      changeset
    end
  end

  defp sessions_overlap?(
         %EventSession{begin: %DateTime{} = a_begin, end: %DateTime{} = a_end},
         %EventSession{begin: %DateTime{} = b_begin, end: %DateTime{} = b_end}
       ) do
    if DateTime.compare(a_begin, b_begin) == :lt do
      DateTime.compare(a_end, b_begin) == :gt
    else
      DateTime.compare(a_begin, b_end) == :lt
    end
  end

  defp sessions_overlap?(%EventSession{}, %EventSession{}), do: false

  defimpl Phoenix.Param, for: DevRound.Events.Event do
    def to_param(%{slug: slug}), do: slug
  end
end
