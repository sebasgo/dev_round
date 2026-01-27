defmodule DevRoundWeb.UserSessionController do
  use DevRoundWeb, :controller

  alias DevRoundWeb.UserAuth

  def create(conn, %{"token" => token}) do
    UserAuth.create_user_session(conn, Base.decode64!(token))
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
