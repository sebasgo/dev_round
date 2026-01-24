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
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> put_resp_header("expires", http_date_one_day_ahead())
    |> send_resp(200, avatar)
  end

  defp http_date_one_day_ahead do
    DateTime.utc_now()
    |> DateTime.add(86400, :second)
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end
end
