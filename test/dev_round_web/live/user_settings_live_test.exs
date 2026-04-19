defmodule DevRoundWeb.UserSettingsLiveTest do
  use DevRoundWeb.ConnCase

  alias DevRound.Accounts
  import Phoenix.LiveViewTest
  import DevRound.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/user/settings")

      assert html =~ "Update Settings"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/user/settings")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log_in"
    end
  end

  describe "profile form form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the full name", %{conn: conn, user: user} do
      new_name = unique_user_name()

      {:ok, lv, _html} = live(conn, ~p"/user/settings")

      result =
        lv
        |> form("#profile_form", %{
          "user" => %{"full_name" => new_name}
        })
        |> render_submit()

      assert result =~ "Profile updated."
      assert Accounts.get_user_by_name(user.name).full_name == new_name
    end
  end
end
