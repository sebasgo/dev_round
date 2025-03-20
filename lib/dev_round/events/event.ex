defmodule DevRound.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset
  alias DevRound.Events.Lang
  alias DevRound.Events.EventAttendee
  alias DevRound.Accounts.User

  schema "events" do
    field :title, :string
    field :location, :string
    field :begin, :utc_datetime
    field :end, :utc_datetime
    field :body, :string
    field :published, :boolean, default: false

    many_to_many :langs, Lang, join_through: "event_langs", on_replace: :delete
    many_to_many :hosts, User, join_through: "event_hosts", on_replace: :delete
    has_many :events_attendees, EventAttendee, on_replace: :delete, on_delete: :delete_all
    has_many :attendees, through: [:events_attendees, :user]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, _opts \\ %{}) do
    event
    |> cast(attrs, [:title, :body, :begin, :end, :location, :published])
    |> validate_required([:title, :body, :begin, :end, :location, :published], message: "Required.")
    |> validate_begin_before_end()
    |> validate_option_selected([:langs, :hosts])
  end

  defp validate_begin_before_end(changeset) do
    begin = get_field(changeset, :begin)
    end_ = get_field(changeset, :end)
    if begin != nil && end_ != nil && Date.compare(begin, end_) != :lt do
      add_error(changeset, :end, "Must be after begin.")
    else
      changeset
    end
  end

  defp validate_option_selected(changeset, [field | remaining]) do
    options = get_field(changeset, field)
    new_changeset = if is_nil(options) || Enum.empty?(options) do
      add_error(changeset, field, "Required.")
    else
      changeset
    end
    validate_option_selected(new_changeset, remaining)
  end

  defp validate_option_selected(changeset, []), do: changeset

end
