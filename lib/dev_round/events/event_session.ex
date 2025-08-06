defmodule DevRound.Events.EventSession do
  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Changeset
  alias DevRound.Events.EventSession
  alias DevRound.Events.Event

  schema "event_sessions" do
    field :title, :string
    field :begin, :utc_datetime
    field :end, :utc_datetime
    field :slug, :string
    field :begin_local, :naive_datetime
    field :end_local, :naive_datetime

    belongs_to :event, Event

    timestamps(type: :utc_datetime)
  end

  def title(%EventSession{title: <<_::binary-size(1), _::binary>> = title}), do: title
  def title(%EventSession{}), do: "Session"

  @doc false
  def changeset(event_session, attrs, _opts \\ %{}) do
    event_session
    |> cast(attrs, [:title, :begin_local, :end_local])
    |> validate_required([:title, :begin_local, :end_local], message: "Required.")
    |> fill_utc_dates(begin_local: :begin, end_local: :end)
    |> validate_begin_before_end()
    |> generate_date_title_slug()
    |> unique_constraint(:slug)
  end
end
