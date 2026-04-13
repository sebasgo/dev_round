defmodule DevRoundWeb.Admin.Filters.UserTokenUserSelect do
  @moduledoc """
  Filter users tokens by user.
  """

  use Backpex.Filters.Select

  alias DevRound.Accounts.User
  alias DevRound.Accounts.UserToken
  alias DevRound.Repo

  @impl Backpex.Filter
  def label, do: "User"

  @impl Backpex.Filters.Select
  def prompt, do: "Select user ..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    query =
      from ut in UserToken,
        join: u in User,
        on: ut.user_id == u.id,
        distinct: u.full_name,
        select: {u.full_name, u.id}

    Repo.all(query)
  end
end
