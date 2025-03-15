defmodule DevRound.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string
    field :location, :string
    field :begin, :utc_datetime
    field :end, :utc_datetime
    field :body, :string
    field :published, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, _opts \\ %{}) do
    event
    |> cast(attrs, [:title, :body, :begin, :end, :location, :published])
    |> validate_required([:title, :body, :begin, :end, :location, :published])
  end
end
