defmodule DevRound.LDAPTest do
  @moduledoc """
  Test suite for DevRound.LDAP module.

  These tests require an LDAP server to be running with the data from
  `contrib/bootstrap.ldif`. To run the LDAP server, use:

      ./contrib/run-openldap-podman

  The tests will be skipped if the LDAP server is not available.
  """

  use DevRound.DataCase, async: true

  alias DevRound.LDAP

  describe "authenticate/2" do
    test "authenticates a valid user" do
      # Test with a known user from bootstrap.ldif
      assert {:ok, user} = LDAP.authenticate("jdoe", "jdoe")

      assert user.name == "jdoe"
      assert user.email == "john.doe@dev.local"
      assert user.full_name == "John Doe"
      assert user.groups == MapSet.new(["dev_round_users", "dev_round_admins"])
    end

    test "fails authentication with wrong password" do
      assert {:error, :invalid_credentials} = LDAP.authenticate("jdoe", "wrongpassword")
    end

    test "fails authentication for non-existent user" do
      assert {:error, :user_not_found} = LDAP.authenticate("nonexistent", "password")
    end
  end

  describe "lookup_user/1" do
    test "looks up an existing user" do
      assert {:ok, user} = LDAP.lookup_user("asmith")

      assert user.name == "asmith"
      assert user.email == "alice.smith@dev.local"
      assert user.full_name == "Alice Smith"
      assert user.groups == MapSet.new(["dev_round_users"])
    end

    test "fails to lookup non-existent user" do
      assert {:error, :user_not_found} = LDAP.lookup_user("nonexistent")
    end
  end
end
