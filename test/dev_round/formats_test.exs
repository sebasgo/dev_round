defmodule DevRound.FormatsTest do
  use DevRound.DataCase, async: true

  alias DevRound.Formats
  alias DevRound.Accounts.User

  describe "format_datetime/1" do
    test "formats datetime correctly" do
      dt = ~U[2025-03-14 16:12:00Z]
      assert Formats.format_datetime(dt) == "14.03.2025 16:12"
    end

    test "formats datetime with different values" do
      dt = ~U[2024-12-25 09:30:45Z]
      assert Formats.format_datetime(dt) == "25.12.2024 09:30"
    end

    test "handles datetime with zero values" do
      dt = ~U[2025-01-01 00:00:00Z]
      assert Formats.format_datetime(dt) == "01.01.2025 00:00"
    end
  end

  describe "format_date/1" do
    test "formats date correctly" do
      dt = ~D[2025-03-14]
      assert Formats.format_date(dt) == "14.03.2025"
    end

    test "formats date with different values" do
      dt = ~D[2024-12-25]
      assert Formats.format_date(dt) == "25.12.2024"
    end

    test "handles date with zero values" do
      dt = ~D[2025-01-01]
      assert Formats.format_date(dt) == "01.01.2025"
    end
  end

  describe "format_time/1" do
    test "formats time correctly" do
      dt = ~T[16:12:00]
      assert Formats.format_time(dt) == "16:12"
    end

    test "formats time with different values" do
      dt = ~T[09:30:45]
      assert Formats.format_time(dt) == "09:30"
    end

    test "handles midnight time" do
      dt = ~T[00:00:00]
      assert Formats.format_time(dt) == "00:00"
    end

    test "handles end of day time" do
      dt = ~T[23:59:59]
      assert Formats.format_time(dt) == "23:59"
    end
  end

  describe "format_datetime_range/2" do
    test "formats same day range correctly" do
      dt1 = ~U[2025-03-14 16:00:00Z]
      dt2 = ~U[2025-03-14 18:00:00Z]
      assert Formats.format_datetime_range(dt1, dt2) == "14.03.2025 16:00 – 18:00"
    end

    test "formats different day range correctly" do
      dt1 = ~U[2025-03-14 16:00:00Z]
      dt2 = ~U[2025-03-15 18:00:00Z]
      assert Formats.format_datetime_range(dt1, dt2) == "14.03.2025 16:00 – 15.03.2025 18:00"
    end

    test "handles same datetime" do
      dt1 = ~U[2025-03-14 16:00:00Z]
      dt2 = ~U[2025-03-14 16:00:00Z]
      assert Formats.format_datetime_range(dt1, dt2) == "14.03.2025 16:00 – 16:00"
    end

    test "handles different years" do
      dt1 = ~U[2024-12-31 23:59:00Z]
      dt2 = ~U[2025-01-01 00:01:00Z]
      assert Formats.format_datetime_range(dt1, dt2) == "31.12.2024 23:59 – 01.01.2025 00:01"
    end
  end

  describe "format_time_range/2" do
    test "formats time range correctly" do
      dt1 = ~T[16:00:00]
      dt2 = ~T[18:00:00]
      assert Formats.format_time_range(dt1, dt2) == "16:00 – 18:00"
    end

    test "handles time range with minutes" do
      dt1 = ~T[09:30:00]
      dt2 = ~T[11:45:00]
      assert Formats.format_time_range(dt1, dt2) == "09:30 – 11:45"
    end

    test "handles midnight range" do
      dt1 = ~T[00:00:00]
      dt2 = ~T[01:00:00]
      assert Formats.format_time_range(dt1, dt2) == "00:00 – 01:00"
    end
  end

  describe "format_datetime_range_compact/2" do
    test "formats only time range if datetime is today" do
      tz = Formats.time_zone()
      {:ok, now} = DateTime.now(tz)
      dt1 = DateTime.to_naive(now) |> NaiveDateTime.truncate(:second) |> DateTime.from_naive!(tz)
      dt1 = %{dt1 | hour: 16, minute: 0, second: 0}
      dt2 = %{dt1 | hour: 18, minute: 0, second: 0}

      assert Formats.format_datetime_range_compact(dt1, dt2) == "16:00 – 18:00"
    end

    test "formats full datetime range if datetime is NOT today" do
      tz = Formats.time_zone()
      {:ok, now} = DateTime.now(tz)
      yesterday = DateTime.add(now, -1, :day)

      dt1 =
        DateTime.to_naive(yesterday)
        |> NaiveDateTime.truncate(:second)
        |> DateTime.from_naive!(tz)

      dt1 = %{dt1 | hour: 16, minute: 0, second: 0}
      dt2 = %{dt1 | hour: 18, minute: 0, second: 0}

      expected = Formats.format_datetime_range(dt1, dt2)
      assert Formats.format_datetime_range_compact(dt1, dt2) == expected
    end

    test "formats full datetime range if start and end are on different days" do
      tz = Formats.time_zone()
      {:ok, now} = DateTime.now(tz)
      dt1 = DateTime.to_naive(now) |> NaiveDateTime.truncate(:second) |> DateTime.from_naive!(tz)
      dt1 = %{dt1 | hour: 23, minute: 0, second: 0}
      tomorrow = DateTime.add(now, 1, :day)

      dt2 =
        DateTime.to_naive(tomorrow) |> NaiveDateTime.truncate(:second) |> DateTime.from_naive!(tz)

      dt2 = %{dt2 | hour: 1, minute: 0, second: 0}

      expected = Formats.format_datetime_range(dt1, dt2)
      assert Formats.format_datetime_range_compact(dt1, dt2) == expected
    end
  end

  describe "format_avatar_placeholder/1" do
    test "generates initials from first and last name" do
      user = %User{avatar: nil, full_name: "John Doe"}
      assert Formats.format_avatar_placeholder(user) == "JD"
    end

    test "handles single name" do
      user = %User{avatar: nil, full_name: "Alice"}
      assert Formats.format_avatar_placeholder(user) == "A"
    end

    test "handles three names" do
      user = %User{avatar: nil, full_name: "John Michael Doe"}
      assert Formats.format_avatar_placeholder(user) == "JD"
    end

    test "handles names with hyphens" do
      user = %User{avatar: nil, full_name: "Jean-Luc Smith"}
      assert Formats.format_avatar_placeholder(user) == "JS"
    end

    test "handles names with spaces" do
      user = %User{avatar: nil, full_name: "Mary Jane Watson"}
      assert Formats.format_avatar_placeholder(user) == "MW"
    end

    test "handles empty name" do
      user = %User{avatar: nil, full_name: ""}
      assert Formats.format_avatar_placeholder(user) == ""
    end

    test "handles name with only spaces" do
      user = %User{avatar: nil, full_name: "   "}
      assert Formats.format_avatar_placeholder(user) == ""
    end
  end

  describe "time_zone/0" do
    test "returns configured time zone" do
      # We can't predict the exact value, but we can verify it's a string
      tz = Formats.time_zone()
      assert is_binary(tz)
      assert tz != ""
    end
  end
end
