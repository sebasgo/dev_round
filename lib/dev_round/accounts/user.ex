defmodule DevRound.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import DevRound.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :full_name, :string
    field :avatar, :string
    field :experience_level, :integer, default: 5

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:name, :email, :full_name, :avatar, :experience_level])
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
