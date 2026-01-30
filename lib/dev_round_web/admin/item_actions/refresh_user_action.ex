defmodule DevRoundWeb.Admin.ItemActions.RefreshUserAction do
  use BackpexWeb, :item_action

  alias DevRound.LDAP
  alias DevRound.Accounts

  @impl Backpex.ItemAction
  def icon(assigns, item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon
      name="hero-arrow-path"
      class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-green-600"
    />
    """
  end

  @impl Backpex.ItemAction
  def label(_assigns, _item), do: "Refresh from LDAP"

  @impl Backpex.ItemAction
  def handle(socket, items, _data) do
    {kind, msg} = items |> Enum.map(&refresh_user/1) |> build_flash_message()

    {:ok, socket |> put_flash(kind, msg)}
  end

  defp refresh_user(user) do
    case LDAP.lookup_user(user.name) do
      {:ok, user_data} -> Accounts.upsert_user(user_data)
      {:error, reason} -> {:error, reason, user}
    end
  end

  defp build_flash_message([{:ok, user}]), do: {:info, "#{user.full_name} refreshed."}

  defp build_flash_message([{:error, :user_not_found, user}]),
    do: {:error, "Error refreshing #{user.full_name}: not found in LDAP dirctory."}

  defp build_flash_message([{:error, _, user}]),
    do: {:error, "Error refreshing #{user.full_name}: internal error."}

  defp build_flash_message(results) do
    n = length(results)

    n_ok =
      Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    {:info, "#{n_ok} of #{n} users refreshed."}
  end
end
