defmodule DevRound.Sessions.TeamName do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_names" do
    field :name, :string
    field :slug, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team_name, attrs ,_opts \\ %{}) do
    team_name
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Slug.slugify(name))
    end
  end
end
