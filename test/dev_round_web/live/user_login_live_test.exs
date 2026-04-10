defmodule DevRoundWeb.UserLoginLiveTest do
  use DevRoundWeb.ConnCase

  import Phoenix.LiveViewTest
  import DevRound.AccountsFixtures

  alias DevRound.LDAP

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")

      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/log_in")
        |> follow_redirect(conn, ~p"/events")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    setup do
      # Mock LDAP.authenticate/2 to return predefined responses
      # This allows tests to run without a real LDAP server

      Mimic.expect(LDAP, :authenticate, fn username, password ->
        case {username, password} do
          {"jdoe", "jdoe"} ->
            {:ok,
             %{
               name: "jdoe",
               email: "john.doe@dev.local",
               full_name: "John Doe",
               avatar: nil,
               groups: MapSet.new(["dev_round_users", "dev_round_admins"])
             }}

          {"asmith", "asmith"} ->
            {:ok,
             %{
               name: "asmith",
               email: "alice.smith@dev.local",
               full_name: "Alice Smith",
               avatar: nil,
               groups: MapSet.new(["dev_round_users"])
             }}

          {"eroberts", "eroberts"} ->
            {:ok,
             %{
               name: "eroberts",
               email: "eve.roberts@dev.local",
               full_name: "Eve Roberts",
               avatar: nil,
               groups: MapSet.new(["some_other_group"])
             }}

          {"asmith", "wrongpassword"} ->
            {:error, :invalid_credentials}

          {"nonexistent", "password"} ->
            {:error, :user_not_found}

          # Default case for any other username/password combinations
          {_, _} ->
            {:ok,
             %{
               name: username,
               email: "#{username}@dev.local",
               full_name: "#{String.capitalize(username)} User",
               avatar: nil,
               groups: MapSet.new(["dev_round_users"])
             }}
        end
      end)

      :ok
    end

    test "stays login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form =
        form(lv, "#login_form", user: %{name: "nonexistent", password: "password"})

      # For error cases, we can check the rendered HTML for flash messages
      html = render_submit(form)

      # Check that the error flash message appears in the rendered HTML
      assert html =~ "Invalid user name or password!"
    end

    test "stays on login page with access denied error for user not in allowed group", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form =
        form(lv, "#login_form", user: %{name: "eroberts", password: "eroberts"})

      # For error cases, we can check the rendered HTML for flash messages
      html = render_submit(form)

      # Check that the access denied flash message appears in the rendered HTML
      assert html =~ "Access to this service is not permitted for your account."
    end
  end
end
