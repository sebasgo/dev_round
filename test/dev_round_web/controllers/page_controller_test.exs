defmodule DevRoundWeb.PageControllerTest do
  use DevRoundWeb.ConnCase

  import DevRound.AccountsFixtures

  describe "Home page" do
    test "redirects to events page", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/")

      assert redirected_to(result) == ~p"/events"
    end

    test "redirects to login on anonyous access", %{conn: conn} do
      result =
        conn
        |> get(~p"/")

      assert redirected_to(result) == ~p"/users/log_in"
    end
  end
end
