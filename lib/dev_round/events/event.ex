defmodule DevRound.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Validation
  alias DevRound.Events.Lang
  alias DevRound.Events.EventAttendee
  alias DevRound.Accounts.User

  schema "events" do
    field :title, :string
    field :location, :string
    field :begin, :utc_datetime
    field :begin_local, :naive_datetime
    field :end, :utc_datetime
    field :end_local, :naive_datetime
    field :body, :string
    field :published, :boolean, default: false
    field :registration_deadline, :utc_datetime
    field :registration_deadline_local, :naive_datetime
    field :slug, :string

    many_to_many :langs, Lang, join_through: "event_langs", on_replace: :delete
    many_to_many :hosts, User, join_through: "event_hosts", on_replace: :delete
    has_many :events_attendees, EventAttendee, on_replace: :delete, on_delete: :delete_all
    has_many :attendees, through: [:events_attendees, :user]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, _opts \\ %{}) do
    event
    |> cast(attrs, [:title, :body, :begin_local, :end_local, :location, :published, :registration_deadline_local])
    |> validate_required([:title, :body, :begin_local, :end_local, :location, :published, :registration_deadline_local], message: "Required.")
    |> fill_utc_dates([begin_local: :begin, end_local: :end, registration_deadline_local: :registration_deadline])
    |> validate_begin_before_end()
    |> validate_registration_deadline_before_begin()
    |> validate_option_selected([:langs, :hosts])
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp validate_begin_before_end(changeset) do
    begin = get_field(changeset, :begin)
    end_ = get_field(changeset, :end)
    if begin != nil && end_ != nil && DateTime.compare(begin, end_) != :lt do
      add_error(changeset, :end_local, "Must be after begin.")
    else
      changeset
    end
  end

  defp validate_registration_deadline_before_begin(changeset) do
    registration_deadline = get_field(changeset, :registration_deadline)
    begin = get_field(changeset, :begin)
    if registration_deadline != nil && begin != nil && DateTime.compare(registration_deadline, begin) != :lt do
      add_error(changeset, :registration_deadline_local, "Must be before begin.")
    else
      changeset
    end
  end

  defp fill_utc_dates(changeset, {from, to}) do
    local_date = get_field(changeset, from)
    utc_date = case(local_date) do
      nil -> nil
      date -> DateTime.from_naive!(date, DevRound.Formats.time_zone()) |> DateTime.shift_zone!("Etc/UTC")
    end
    put_change(changeset, to, utc_date)
  end

  defp fill_utc_dates(changeset, opts) do
    Enum.reduce(opts, changeset, fn opt, changeset -> fill_utc_dates(changeset, opt) end)
  end

  defp generate_slug(changeset) do
    case get_field(changeset, :title) do
      nil -> changeset
      title -> case(get_field(changeset, :begin_local)) do
        nil -> changeset
        begin ->
          slug_data = "#{Calendar.strftime(begin, "%Y-%m-%d")}-#{title}"
          put_change(changeset, :slug, Slug.slugify(slug_data))
      end
    end
  end

  defimpl Phoenix.Param, for: DevRound.Events.Event do
    def to_param(%{slug: slug}), do: slug
  end

end
