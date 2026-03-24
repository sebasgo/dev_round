defmodule DevRound.Formats do
  @moduledoc """
  Utility module for formatting dates, times, and user data for display.

  This module provides functions to format various datetime types and user information
  in a consistent way throughout the application. All datetime formatting uses the
  Calendar.strftime/2 function with custom format strings.

  ## Date and Time Formatting

  The module provides several formatting functions that follow these conventions:
  - Dates: "dd.mm.yyyy" format (e.g., "14.03.2025")
  - Times: "hh:mm" format (24-hour clock, e.g., "16:12")
  - Datetimes: "dd.mm.yyyy hh:mm" format (e.g., "14.03.2025 16:12")

  ## Avatar Placeholder

  For users without an avatar image, the module generates initials from the user's
  full name by taking the first letter of the first name and the first letter of the
  last name.

  ## Time Zone Configuration

  The time zone is retrieved from the application configuration and used for
  converting between UTC and local times elsewhere in the application.
  """

  @doc """
  Formats a datetime into a human-readable string.

  ## Examples

      iex> format_datetime(~U[2025-03-14 16:12:00Z])
      "14.03.2025 16:12"

  ## Parameters

  - `dt`: A datetime value (DateTime, NaiveDateTime, or similar)

  ## Returns

  A formatted string in "dd.mm.yyyy hh:mm" format.
  """
  def format_datetime(dt) do
    Calendar.strftime(dt, "%d.%m.%Y %H:%M")
  end

  @doc """
  Formats a date into a human-readable string.

  ## Examples

      iex> format_date(~D[2025-03-14])
      "14.03.2025"

  ## Parameters

  - `dt`: A date value (Date, NaiveDateTime, or similar)

  ## Returns

  A formatted string in "dd.mm.yyyy" format.
  """
  def format_date(dt) do
    Calendar.strftime(dt, "%d.%m.%Y")
  end

  @doc """
  Formats a time into a human-readable string.

  ## Examples

      iex> format_time(~T[16:12:00])
      "16:12"

  ## Parameters

  - `dt`: A time value (Time, NaiveDateTime, or similar)

  ## Returns

  A formatted string in "hh:mm" format (24-hour clock).
  """
  def format_time(dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  @doc """
  Formats a datetime range into a human-readable string.

  The formatting adapts based on whether the dates are the same:
  - Same day: Shows date once with time range (e.g., "14.03.2025 16:00 – 18:00")
  - Different days: Shows full datetime for both (e.g., "14.03.2025 16:00 – 15.03.2025 18:00")

  ## Examples

      iex> format_datetime_range(~U[2025-03-14 16:00:00Z], ~U[2025-03-14 18:00:00Z])
      "14.03.2025 16:00 – 14.03.2025 18:00"

      iex> format_datetime_range(~U[2025-03-14 16:00:00Z], ~U[2025-03-15 18:00:00Z])
      "14.03.2025 16:00 – 15.03.2025 18:00"

  ## Parameters

  - `dt1`: The start datetime
  - `dt2`: The end datetime

  ## Returns

  A formatted string representing the date/time range.
  """
  def format_datetime_range(dt1, dt2) do
    if Date.compare(dt1, dt2) == :eq do
      "#{format_date(dt1)} #{format_time(dt1)} – #{format_time(dt2)}"
    else
      "#{format_datetime(dt1)} – #{format_datetime(dt2)}"
    end
  end

  @doc """
  Formats a time range into a human-readable string.

  ## Examples

      iex> format_time_range(~T[16:00:00], ~T[18:00:00])
      "16:00 – 18:00"

  ## Parameters

  - `dt1`: The start time
  - `dt2`: The end time

  ## Returns

  A formatted string in "hh:mm – hh:mm" format.
  """
  def format_time_range(dt1, dt2) do
    "#{format_time(dt1)} – #{format_time(dt2)}"
  end

  @doc """
  Formats a datetime range into a compact string.

  The formatting adapts based on whether the dates are the same and match the current date:
  - Today and same day: Shows time range (e.g., "16:00 – 18:00")
  - Otherwise: Shows full datetime range (see `format_datetime_range/2`)

  ## Examples

      iex> format_datetime_range_compact(~U[2026-03-24 16:00:00Z], ~U[2026-03-24 18:00:00Z])
      "16:00 – 18:00"

      iex> format_datetime_range_compact(~U[2025-03-14 16:00:00Z], ~U[2025-03-15 18:00:00Z])
      "14.03.2025 16:00 – 15.03.2025 18:00"

  ## Parameters

  - `dt1`: The start datetime
  - `dt2`: The end datetime

  ## Returns

  A formatted string representing the date/time range or just the time range.
  """
  def format_datetime_range_compact(dt1, dt2) do
    {:ok, now} = DateTime.now(dt1.time_zone)

    if Date.compare(now, dt1) == :eq and Date.compare(dt1, dt2) == :eq do
      format_time_range(dt1, dt2)
    else
      format_datetime_range(dt1, dt2)
    end
  end

  @doc """
  Generates an avatar placeholder from a user's full name.

  Creates initials by taking the first letter of the first name and the first
  letter of the last name. If the name has only one part, uses the first letter
  twice.

  ## Examples

      iex> user = %DevRound.Accounts.User{avatar: nil, full_name: "John Doe"}
      iex> format_avatar_placeholder(user)
      "JD"

      iex> user = %DevRound.Accounts.User{avatar: nil, full_name: "Alice"}
      iex> format_avatar_placeholder(user)
      "AA"

  ## Parameters

  - `user`: A User struct with `avatar` and `full_name` fields

  ## Returns

  A string containing the initials (two characters).

  ## Note

  This function expects the user to have `avatar: nil`. If the user has an avatar,
  this function will not be used.
  """
  def format_avatar_placeholder(%DevRound.Accounts.User{avatar: nil, full_name: full_name}) do
    parts = String.split(full_name, " ")
    non_empty_parts = Enum.filter(parts, &(&1 != ""))

    cond do
      length(non_empty_parts) >= 2 ->
        String.first(hd(non_empty_parts)) <> String.first(List.last(non_empty_parts))

      length(non_empty_parts) == 1 ->
        String.first(hd(non_empty_parts))

      true ->
        ""
    end
  end

  @doc """
  Retrieves the application's configured time zone.

  ## Examples

      iex> time_zone()
      "Europe/Berlin"

  ## Returns

  The time zone string configured in the application environment.
  """
  def time_zone, do: Application.get_env(:dev_round, :time_zone)
end
