defmodule DevRound.AccountsTest do
  use DevRound.DataCase

  alias DevRound.Accounts
  alias DevRound.LDAP

  import DevRound.AccountsFixtures
  alias DevRound.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_name/1" do
    test "does not return the user if the name does not exist" do
      refute Accounts.get_user_by_name("unknown")
    end

    test "returns the user if the name exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_name(user.name)
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "authenticate_user_via_ldap/2" do
    setup do
      # Mock LDAP.authenticate/2 to return predefined responses
      # This allows tests to run without a real LDAP server

      # Single expectation that handles all cases
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

          {"avataruser", "avatarpass"} ->
            {:ok,
             %{
               name: "avataruser",
               email: "avatar.user@dev.local",
               full_name: "Avatar User",
               avatar:
                 <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01,
                   0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00>>,
               groups: MapSet.new(["dev_round_users"])
             }}

          # Default case for any other username/password combinations
          {_, _} ->
            {:ok,
             %{
               name: username,
               email: "#{username}@dev.local",
               full_name:
                 String.replace(username, ~r/^([a-z])([a-z]+)$/, fn _, first, rest ->
                   "#{String.upcase(first)} #{String.capitalize(rest)}"
                 end),
               avatar: nil,
               groups: MapSet.new(["dev_round_users"])
             }}
        end
      end)

      :ok
    end

    test "creates a new user on first successful LDAP authentication" do
      # Test with a known user from bootstrap.ldif
      # asmith is in the dev_round_users group
      assert {:ok, user} = Accounts.authenticate_user_via_ldap("asmith", "asmith")

      assert user.name == "asmith"
      assert user.email == "alice.smith@dev.local"
      assert user.full_name == "Alice Smith"
      assert user.role == :user
    end

    test "returns existing user on subsequent LDAP authentications" do
      # Create user first
      user = user_fixture(%{name: "asmith", email: "alice.smith@dev.local"})

      # Authenticate again - should return the same user
      assert {:ok, returned_user} = Accounts.authenticate_user_via_ldap("asmith", "asmith")
      assert returned_user.id == user.id
      assert returned_user.name == "asmith"
    end

    test "returns error if user is not in the allowed group" do
      # Test with a user that exists but is not in the allowed group
      assert {:error, :access_denied} =
               Accounts.authenticate_user_via_ldap("eroberts", "eroberts")
    end

    test "creates admin user if in admin group" do
      # Test with jdoe who is in both dev_round_users and dev_round_admins
      assert {:ok, user} = Accounts.authenticate_user_via_ldap("jdoe", "jdoe")

      assert user.name == "jdoe"
      assert user.role == :admin
    end

    test "returns error for invalid credentials" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user_via_ldap("asmith", "wrongpassword")
    end

    test "returns error for non-existent user" do
      assert {:error, :user_not_found} =
               Accounts.authenticate_user_via_ldap("nonexistent", "password")
    end

    test "processes avatar data correctly" do
      # Test avatar processing with static hash verification
      # Using sample JPEG binary data and pre-calculated SHA hash
      avatar_data =
        <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01,
          0x00, 0x48, 0x00, 0x48, 0x00, 0x00>>

      expected_hash =
        <<0xF3, 0xD9, 0x70, 0xCC, 0x7F, 0xE0, 0xFA, 0xB9, 0x6F, 0xC7, 0x17, 0xFC, 0xE3, 0x4C,
          0xFF, 0x9E, 0xE9, 0x0F, 0x21, 0x27>>

      # Mock LDAP to return avatar data
      Mimic.expect(LDAP, :authenticate, fn "avataruser", "avatarpass" ->
        {:ok,
         %{
           name: "avataruser",
           email: "avatar.user@dev.local",
           full_name: "Avatar User",
           avatar: avatar_data,
           groups: MapSet.new(["dev_round_users"])
         }}
      end)

      # Authenticate user with avatar
      assert {:ok, user} = Accounts.authenticate_user_via_ldap("avataruser", "avatarpass")

      # Verify avatar data is stored correctly
      assert user.avatar == avatar_data

      # Verify avatar hash is stored correctly (using pre-calculated static hash)
      assert user.avatar_hash == expected_hash
    end
  end

  describe "upsert_user/1" do
    test "inserts a new user" do
      attrs = %{
        name: "newuser",
        email: "new@example.com",
        full_name: "New User",
        avatar: nil,
        groups: MapSet.new(["dev_round_users"])
      }

      assert {:ok, %User{} = user} = Accounts.upsert_user(attrs)
      assert user.name == "newuser"
      assert user.email == "new@example.com"
      assert user.full_name == "New User"
    end

    test "updates existing user" do
      user = user_fixture(%{name: "existing", email: "old@example.com"})

      attrs = %{
        name: "existing",
        email: "updated@example.com",
        full_name: "Updated User",
        avatar: nil,
        groups: MapSet.new(["dev_round_users"])
      }

      assert {:ok, %User{} = updated_user} = Accounts.upsert_user(attrs)
      assert updated_user.id == user.id
      assert updated_user.email == "updated@example.com"
      assert updated_user.full_name == "Updated User"
    end
  end

  describe "change_user_profile/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_profile(%User{})
      assert changeset.required == [:full_name]
    end

    test "allows fields to be set" do
      changeset = Accounts.change_user_profile(%User{}, %{full_name: "New Full Name"})
      assert changeset.valid?
      assert get_change(changeset, :full_name) == "New Full Name"
    end
  end

  describe "apply_user_profile/2" do
    test "updates the user profile" do
      user = user_fixture(%{full_name: "Old Name"})
      {:ok, updated_user} = Accounts.apply_user_profile(user, %{full_name: "New Name"})
      assert updated_user.full_name == "New Name"
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end
end
