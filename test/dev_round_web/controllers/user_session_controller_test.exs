defmodule DevRoundWeb.UserSessionControllerTest do
  use DevRoundWeb.ConnCase

  import DevRound.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/create_session" do
    test "redirects to events page with valid token", %{conn: conn} do
      # Test with a valid (but fake) token that can be decoded
      # This validates the normal redirect behavior to ~p"/events"
      conn =
        get(conn, ~p"/users/create_session", %{
          "token" => Base.url_encode64("fake_token_data")
        })

      # Should redirect to events page (signed_in_path)
      assert redirected_to(conn) == ~p"/events"
    end

    test "redirects to return_to path when set", %{conn: conn} do
      # Set a return_to path like the original tests did
      conn = conn |> init_test_session(user_return_to: "/foo/bar")

      # Test with a valid (but fake) token that can be decoded
      # This validates the redirect behavior with custom return path
      conn =
        get(conn, ~p"/users/create_session", %{
          "token" => Base.url_encode64("fake_token_data")
        })

      # Should redirect to the return_to path
      assert redirected_to(conn) == "/foo/bar"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
