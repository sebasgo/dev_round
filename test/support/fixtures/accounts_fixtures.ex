defmodule DevRound.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DevRound.Accounts` context.
  """

  alias DevRound.Repo
  alias DevRound.Accounts.User

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def unique_user_name, do: "user#{System.unique_integer()}"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_user_name(),
      email: unique_user_email(),
      full_name: "Test User"
    })
  end

  def user_fixture(attrs \\ %{}) do
    attrs = valid_user_attributes(attrs)

    %User{}
    |> User.upsert_changeset(attrs)
    |> Repo.insert!()
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
