defmodule DevRoundWeb.AvatarController do
  use DevRoundWeb, :controller

  alias DevRound.Accounts
  alias DevRound.Accounts.User

  def show(conn, %{"name" => user_name}) do
    %User{avatar: avatar} = Accounts.get_user_by_name(user_name)
    send_avatar_data(conn, avatar)
  end

  defp send_avatar_data(conn, avatar) when not is_nil(avatar) do
    conn
    |> put_resp_content_type("image/jpeg")
    |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
    |> send_resp(200, avatar)
  end
end
