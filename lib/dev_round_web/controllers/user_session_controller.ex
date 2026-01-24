defmodule DevRoundWeb.UserSessionController do
  use DevRoundWeb, :controller

  alias DevRound.Accounts
  alias DevRoundWeb.UserAuth

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"name" => name, "password" => password} = user_params

    case Accounts.authenticate_user_via_ldap(name, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid user name or password!")
        |> redirect(to: ~p"/users/log_in")

      {:error, :access_denied} ->
        conn
        |> put_flash(:error, "Access to this service is not permitted for your account.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
