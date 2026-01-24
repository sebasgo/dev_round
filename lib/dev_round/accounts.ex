defmodule DevRound.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias DevRound.Repo
  alias DevRound.LDAP

  alias DevRound.Accounts.{User, UserToken}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_name(name) when is_binary(name) do
    Repo.get_by(User, name: name)
  end

  @doc """
  Authenticates a user via LDAP and returns the user.
  Creates a new user record if this is their first login.
  """
  def authenticate_user_via_ldap(user, password) do
    case LDAP.authenticate(user, password) do
      {:ok, ldap_attrs} ->
        if MapSet.member?(ldap_attrs.groups, Application.get_env(:dev_round, :ldap_user_group)) do
          upsert_user(ldap_attrs)
        else
          {:error, :access_denied}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Inserts or updates a user with the given attributes.
  """
  def upsert_user(attrs) do
    %User{}
    |> User.upsert_changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:name],
      returning: [:inserted_at]
    )
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def apply_user_profile(user, attrs) do
    User.profile_changeset(user, attrs)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end
end
