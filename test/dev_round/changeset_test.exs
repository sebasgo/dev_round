defmodule DevRound.ChangesetTest do
  use DevRound.DataCase, async: true

  describe "validate_option_selected/2" do
    test "adds error when field is nil" do
      # Create a changeset with a field that has nil value
      data = %{}
      types = %{tags: {:array, :string}}
      params = %{tags: nil}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:tags])
        |> DevRound.Changeset.validate_option_selected([:tags])

      assert %{errors: [tags: {"Required.", _}]} = changeset
    end

    test "adds error when field is empty list" do
      # Create a changeset with a field that has empty list value
      data = %{}
      types = %{tags: {:array, :string}}
      params = %{tags: []}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:tags])
        |> DevRound.Changeset.validate_option_selected([:tags])

      assert %{errors: [tags: {"Required.", _}]} = changeset
    end

    test "does not add error when field has values" do
      # Create a changeset with a field that has values
      data = %{}
      types = %{tags: {:array, :string}}
      params = %{tags: ["tag1"]}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:tags])
        |> DevRound.Changeset.validate_option_selected([:tags])

      refute changeset.errors[:tags]
    end

    test "validates multiple fields" do
      # Create a changeset with multiple fields
      data = %{}
      types = %{tags: {:array, :string}, hosts: {:array, :string}}
      params = %{tags: [], hosts: []}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:tags, :hosts])
        |> DevRound.Changeset.validate_option_selected([:tags, :hosts])

      # Check that both fields have errors
      assert changeset.errors[:tags] != nil
      assert changeset.errors[:hosts] != nil
    end
  end

  describe "validate_experience_level/1" do
    test "accepts valid experience level (0-9)" do
      data = %{}
      types = %{experience_level: :integer}
      params = %{experience_level: 5}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:experience_level])
        |> DevRound.Changeset.validate_experience_level()

      refute changeset.errors[:experience_level]
    end

    test "rejects experience level less than 0" do
      data = %{}
      types = %{experience_level: :integer}
      params = %{experience_level: -1}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:experience_level])
        |> DevRound.Changeset.validate_experience_level()

      assert %{errors: [experience_level: {"Must be between 0 and 9 inclusive.", _}]} = changeset
    end

    test "rejects experience level greater than or equal to 10" do
      data = %{}
      types = %{experience_level: :integer}
      params = %{experience_level: 10}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:experience_level])
        |> DevRound.Changeset.validate_experience_level()

      assert %{errors: [experience_level: {"Must be between 0 and 9 inclusive.", _}]} = changeset
    end

    test "rejects non-numeric experience level" do
      data = %{}
      types = %{experience_level: :integer}
      params = %{experience_level: "invalid"}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:experience_level])
        |> DevRound.Changeset.validate_experience_level()

      # When casting fails, we get a cast error, not a validation error
      assert %{errors: [experience_level: {"is invalid", _}]} = changeset
    end
  end

  describe "validate_begin_before_end/1" do
    test "accepts valid begin before end" do
      data = %{}
      types = %{begin: :utc_datetime, end: :utc_datetime}

      params = %{
        begin: ~U[2025-03-14 16:12:00Z],
        end: ~U[2025-03-14 17:12:00Z]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin, :end])
        |> DevRound.Changeset.validate_begin_before_end()

      refute changeset.errors[:end_local]
    end

    test "rejects begin equal to end" do
      data = %{}
      types = %{begin: :utc_datetime, end: :utc_datetime}

      params = %{
        begin: ~U[2025-03-14 16:12:00Z],
        end: ~U[2025-03-14 16:12:00Z]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin, :end])
        |> DevRound.Changeset.validate_begin_before_end()

      assert %{errors: [end_local: {"Must be after begin.", _}]} = changeset
    end

    test "rejects begin after end" do
      data = %{}
      types = %{begin: :utc_datetime, end: :utc_datetime}

      params = %{
        begin: ~U[2025-03-14 17:12:00Z],
        end: ~U[2025-03-14 16:12:00Z]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin, :end])
        |> DevRound.Changeset.validate_begin_before_end()

      assert %{errors: [end_local: {"Must be after begin.", _}]} = changeset
    end

    test "accepts nil begin" do
      data = %{}
      types = %{begin: :utc_datetime, end: :utc_datetime}

      params = %{
        begin: nil,
        end: ~U[2025-03-14 16:12:00Z]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin, :end])
        |> DevRound.Changeset.validate_begin_before_end()

      refute changeset.errors[:end_local]
    end

    test "accepts nil end" do
      data = %{}
      types = %{begin: :utc_datetime, end: :utc_datetime}

      params = %{
        begin: ~U[2025-03-14 16:12:00Z],
        end: nil
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin, :end])
        |> DevRound.Changeset.validate_begin_before_end()

      refute changeset.errors[:end_local]
    end
  end

  describe "fill_utc_dates/2" do
    test "converts local datetime to UTC" do
      data = %{}
      types = %{begin_local: :naive_datetime, begin: :utc_datetime}
      params = %{begin_local: ~N[2025-03-14 16:12:00]}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin_local])
        |> DevRound.Changeset.fill_utc_dates({:begin_local, :begin})

      assert changeset.changes[:begin] != nil
    end

    test "handles nil local datetime" do
      data = %{}
      types = %{begin_local: :naive_datetime, begin: :utc_datetime}
      params = %{begin_local: nil}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin_local])
        |> DevRound.Changeset.fill_utc_dates({:begin_local, :begin})

      assert changeset.changes[:begin] == nil
    end

    test "handles multiple date conversions" do
      data = %{}

      types = %{
        begin_local: :naive_datetime,
        end_local: :naive_datetime,
        begin: :utc_datetime,
        end: :utc_datetime
      }

      params = %{
        begin_local: ~N[2025-03-14 16:12:00],
        end_local: ~N[2025-03-14 17:12:00]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:begin_local, :end_local])
        |> DevRound.Changeset.fill_utc_dates([
          {:begin_local, :begin},
          {:end_local, :end}
        ])

      assert changeset.changes[:begin] != nil
      assert changeset.changes[:end] != nil
    end
  end

  describe "generate_date_title_slug/1" do
    test "generates slug from date and title" do
      data = %{}
      types = %{title: :string, begin_local: :naive_datetime, slug: :string}

      params = %{
        title: "My Event Title",
        begin_local: ~N[2025-03-14 16:12:00]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:title, :begin_local])
        |> DevRound.Changeset.generate_date_title_slug()

      assert changeset.changes[:slug] == "2025-03-14-my-event-title"
    end

    test "handles nil title" do
      data = %{}
      types = %{title: :string, begin_local: :naive_datetime, slug: :string}

      params = %{
        title: nil,
        begin_local: ~N[2025-03-14 16:12:00]
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:title, :begin_local])
        |> DevRound.Changeset.generate_date_title_slug()

      refute Map.has_key?(changeset.changes, :slug)
    end

    test "handles nil begin date" do
      data = %{}
      types = %{title: :string, begin_local: :naive_datetime, slug: :string}

      params = %{
        title: "My Event Title",
        begin_local: nil
      }

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, [:title, :begin_local])
        |> DevRound.Changeset.generate_date_title_slug()

      refute Map.has_key?(changeset.changes, :slug)
    end
  end
end
