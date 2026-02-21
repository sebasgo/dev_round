defmodule DevRound.UserImport do
  @moduledoc """
  Module for importing users from JSON files.

  Provides functionality to import user data from JSON files into the
  application database, handling duplicates gracefully by skipping them.
  """

  alias DevRound.Repo
  alias DevRound.Accounts.User
  alias Ecto.Changeset

  @doc """
  Imports users from a JSON file.

  ## Parameters
  - file_path: Path to the JSON file containing user data

  ## Returns
  - {:ok, %{imported: count, skipped: count, errors: [error_list]}}

  ## Example JSON format:
  ```json
  [
    {"name": "jdoe", "email": "john@example.com", "experience_level": 5, "full_name": "John Doe"},
    {"name": "jsmith", "email": "jane@example.com", "experience_level": 0, "full_name": "Jane Smith"}
  ]
  ```
  """
  def import_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, users_data} ->
            import_users(users_data)

          {:error, decode_error} ->
            {:error, "Failed to decode JSON: #{inspect(decode_error)}"}
        end

      {:error, file_error} ->
        {:error, "Failed to read file: #{inspect(file_error)}"}
    end
  end

  @doc """
  Imports a list of user data maps.
  """
  def import_users(users_data) when is_list(users_data) do
    results = %{imported: 0, skipped: 0, errors: []}

    Enum.reduce(users_data, results, fn user_data, acc ->
      case import_single_user(user_data) do
        {:ok, _user} ->
          %{acc | imported: acc.imported + 1}

        {:error, :unique_constraint} ->
          %{acc | skipped: acc.skipped + 1}

        {:error, reason} ->
          error_msg = format_error(user_data, reason)
          %{acc | errors: [error_msg | acc.errors]}
      end
    end)
    |> then(fn results ->
      {:ok, %{results | errors: Enum.reverse(results.errors)}}
    end)
  end

  defp import_single_user(user_data) do
    changeset = User.upsert_changeset(%User{}, user_data)

    case Repo.insert(changeset) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Changeset{errors: errors}} ->
        if has_unique_constraint_error?(errors) do
          {:error, :unique_constraint}
        else
          {:error, errors}
        end
    end
  end

  defp has_unique_constraint_error?(errors) do
    Enum.any?(errors, fn {_field, {_message, opts}} ->
      Keyword.get(opts, :constraint) == :unique or
        Keyword.get(opts, :validation) == :unsafe_unique
    end)
  end

  defp format_error(user_data, reason) do
    user_info = "#{user_data["name"]} (#{user_data["email"]})"
    "Failed to import user #{user_info}: #{inspect(reason)}"
  end

  @doc """
  Convenience function to run the import and print results.
  """
  def run_import(file_path) do
    IO.puts("Starting user import from: #{file_path}")

    case import_from_file(file_path) do
      {:ok, result} -> handle_import_success(result)
      {:error, reason} -> handle_import_error(reason)
    end
  end

  defp handle_import_success(%{imported: imported, skipped: skipped, errors: errors}) do
    IO.puts("Import completed:")
    IO.puts("  - Imported: #{imported} users")
    IO.puts("  - Skipped (duplicates): #{skipped} users")

    if errors != [] do
      IO.puts("  - Errors: #{length(errors)}")

      Enum.each(errors, fn error ->
        IO.puts("    * #{error}")
      end)
    end

    {:ok, %{imported: imported, skipped: skipped, errors: errors}}
  end

  defp handle_import_error(reason) do
    IO.puts("Import failed: #{reason}")
    {:error, reason}
  end
end
