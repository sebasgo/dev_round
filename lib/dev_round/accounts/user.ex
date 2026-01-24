defmodule DevRound.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :full_name, :string
    field :avatar, :binary
    field :avatar_hash, :binary
    field :experience_level, :integer, default: 5

    timestamps(type: :utc_datetime)
  end

  def upsert_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:name, :email, :full_name, :avatar, :experience_level])
    |> update_avatar_hash()
    |> validate_name(opts)
    |> validate_email(opts)
  end

  def profile_changeset(user, attrs, _opts \\ []) do
    user
    |> cast(attrs, [:full_name])
    |> validate_required(:full_name)
  end

  def admin_changeset(user, attrs, _opts \\ []) do
    user
    |> cast(attrs, [:experience_level])
    |> validate_required(:experience_level)
    |> validate_experience_level()
  end

  defp validate_name(changeset, _opts) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, max: 160)
    |> unique_constraint(:name)
  end

  defp validate_email(changeset, _opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  defp update_avatar_hash(changeset) do
    case get_field(changeset, :avatar) do
      nil ->
        changeset
        |> put_change(:avatar_hash, nil)

      avatar ->
        changeset
        |> put_change(:avatar_hash, :crypto.hash(:sha, avatar))
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  defimpl Phoenix.Param, for: DevRound.Accounts.User do
    def to_param(%{name: name}), do: name
  end
end
