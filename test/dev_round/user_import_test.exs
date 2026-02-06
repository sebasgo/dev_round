defmodule DevRound.UserImportTest do
  use DevRound.DataCase

  alias DevRound.UserImport
  alias DevRound.Accounts.User
  alias DevRound.AccountsFixtures

  describe "import_from_file/1" do
    test "imports valid users from a JSON file" do
      file_path = Path.expand("../support/fixtures/user_import/valid_users.json", __DIR__)

      assert {:ok, %{imported: 3, skipped: 0, errors: []}} =
               UserImport.import_from_file(file_path)
    end

    test "handles non-existent file" do
      assert {:error, _reason} = UserImport.import_from_file("/nonexistent/file.json")
    end

    test "handles invalid JSON" do
      file_path = Path.expand("../support/fixtures/user_import/invalid_json.json", __DIR__)

      assert {:error, _reason} = UserImport.import_from_file(file_path)
    end

    test "handles empty JSON array" do
      file_path = Path.expand("../support/fixtures/user_import/empty.json", __DIR__)

      assert {:ok, %{imported: 0, skipped: 0, errors: []}} =
               UserImport.import_from_file(file_path)
    end
  end

  describe "import_users/1" do
    test "imports valid users successfully" do
      users = [
        %{
          "name" => "jdoe",
          "email" => "john@example.com",
          "experience_level" => 5,
          "full_name" => "John Doe"
        },
        %{
          "name" => "asmith",
          "email" => "alice@example.com",
          "experience_level" => 3,
          "full_name" => "Alice Smith"
        }
      ]

      assert {:ok, %{imported: 2, skipped: 0, errors: []}} = UserImport.import_users(users)
    end

    test "skips duplicate users" do
      _user =
        AccountsFixtures.user_fixture(%{
          name: "existing",
          email: "existing@example.com",
          full_name: "Existing User"
        })

      users = [
        %{
          "name" => "existing",
          "email" => "existing@example.com",
          "experience_level" => 5,
          "full_name" => "Existing User"
        }
      ]

      assert {:ok, %{imported: 0, skipped: 1, errors: []}} = UserImport.import_users(users)
    end

    test "handles missing required name field" do
      users = [
        %{"email" => "test@example.com", "experience_level" => 5, "full_name" => "Test User"}
      ]

      assert {:ok, %{imported: 0, skipped: 0, errors: [error]}} = UserImport.import_users(users)
      assert error =~ "can't be blank"
    end

    test "handles missing required email field" do
      users = [%{"name" => "test", "experience_level" => 5, "full_name" => "Test User"}]

      assert {:ok, %{imported: 0, skipped: 0, errors: [error]}} = UserImport.import_users(users)
      assert error =~ "can't be blank"
    end

    test "handles invalid email format" do
      users = [
        %{
          "name" => "test",
          "email" => "invalid-email",
          "experience_level" => 5,
          "full_name" => "Test User"
        }
      ]

      assert {:ok, %{imported: 0, skipped: 0, errors: [error]}} = UserImport.import_users(users)
      assert error =~ "must have the @ sign and no spaces"
    end

    test "handles mixed valid and invalid users" do
      users = [
        %{
          "name" => "valid1",
          "email" => "valid1@example.com",
          "experience_level" => 5,
          "full_name" => "Valid User 1"
        },
        %{
          "name" => "valid2",
          "email" => "valid2@example.com",
          "experience_level" => 3,
          "full_name" => "Valid User 2"
        },
        %{
          "name" => "invalid",
          "email" => "invalid-email",
          "experience_level" => 5,
          "full_name" => "Invalid User"
        },
        %{
          "name" => "duplicate1",
          "email" => "duplicate1@example.com",
          "experience_level" => 7,
          "full_name" => "Duplicate User 1"
        },
        %{
          "name" => "duplicate2",
          "email" => "duplicate2@example.com",
          "experience_level" => 8,
          "full_name" => "Duplicate User 2"
        }
      ]

      # First create the duplicate users
      AccountsFixtures.user_fixture(%{
        name: "duplicate1",
        email: "duplicate1@example.com",
        full_name: "Duplicate User 1"
      })

      AccountsFixtures.user_fixture(%{
        name: "duplicate2",
        email: "duplicate2@example.com",
        full_name: "Duplicate User 2"
      })

      assert {:ok, %{imported: 2, skipped: 2, errors: [error]}} = UserImport.import_users(users)
      assert error =~ "must have the @ sign and no spaces"
    end

    test "handles optional role field" do
      users = [
        %{
          "name" => "admin",
          "email" => "admin@example.com",
          "experience_level" => 5,
          "role" => "admin",
          "full_name" => "Admin User"
        },
        %{
          "name" => "user",
          "email" => "user@example.com",
          "experience_level" => 3,
          "role" => "user",
          "full_name" => "Regular User"
        }
      ]

      assert {:ok, %{imported: 2, skipped: 0, errors: []}} = UserImport.import_users(users)
      admin = Repo.get_by(User, email: "admin@example.com")
      regular_user = Repo.get_by(User, email: "user@example.com")
      assert admin.role == :admin
      assert regular_user.role == :user
    end
  end

  describe "run_import/1" do
    test "prints import results to console" do
      file_path = Path.expand("../support/fixtures/user_import/valid_users.json", __DIR__)

      # Just test that it doesn't crash
      assert {:ok, %{imported: 3, skipped: 0, errors: []}} = UserImport.run_import(file_path)
    end

    test "prints error messages for failed imports" do
      file_path = Path.expand("../support/fixtures/user_import/invalid_users.json", __DIR__)

      # Just test that it doesn't crash
      assert {:ok, %{imported: 2, skipped: 0, errors: [_]}} = UserImport.run_import(file_path)
    end
  end
end
