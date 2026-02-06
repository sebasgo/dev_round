defmodule DevRound.Changeset do
  @moduledoc """
  Helper functions for working with Ecto changesets.

  This module provides utility functions for common changeset validations
  and transformations used throughout the application.
  """

  import Ecto.Changeset

  @doc """
  Validates that the given fields have at least one selected option.

  This function checks if the specified fields contain any values (not nil or empty list).
  If a field is nil or empty, it adds a "Required." error to that field.

  ## Examples

      iex> changeset = Ecto.Changeset.cast(%Ecto.Changeset{}, %{tags: []}, [:tags])
      iex> Changeset.validate_option_selected(changeset, [:tags])
      # Adds error to tags field

      iex> changeset = Ecto.Changeset.cast(%Ecto.Changeset{}, %{tags: ["tag1"]}, [:tags])
      iex> Changeset.validate_option_selected(changeset, [:tags])
      # No error added

  """
  def validate_option_selected(changeset, [field | remaining]) do
    options = get_field(changeset, field)

    new_changeset =
      if is_nil(options) || Enum.empty?(options) do
        add_error(changeset, field, "Required.")
      else
        changeset
      end

    validate_option_selected(new_changeset, remaining)
  end

  def validate_option_selected(changeset, []), do: changeset

  @doc """
  Validates that the experience level is between 0 and 9 inclusive.

  ## Examples

      iex> changeset = %Ecto.Changeset{changes: %{experience_level: 5}}
      iex> Changeset.validate_experience_level(changeset)
      # No error added

      iex> changeset = %Ecto.Changeset{changes: %{experience_level: 10}}
      iex> Changeset.validate_experience_level(changeset)
      # Adds error to experience_level field

  """
  def validate_experience_level(changeset) do
    changeset
    |> validate_number(:experience_level,
      greater_than_or_equal_to: 0,
      less_than: 10,
      message: "Must be between 0 and 9 inclusive."
    )
  end

  @doc """
  Validates that begin datetime is before end datetime.

  Adds an error to :end_local field if begin is not before end.

  ## Examples

      iex> changeset = %Ecto.Changeset{changes: %{begin: ~U[2025-03-14 16:12:00Z], end: ~U[2025-03-14 17:12:00Z]}}
      iex> Changeset.validate_begin_before_end(changeset)
      # No error added

      iex> changeset = %Ecto.Changeset{changes: %{begin: ~U[2025-03-14 17:12:00Z], end: ~U[2025-03-14 16:12:00Z]}}
      iex> Changeset.validate_begin_before_end(changeset)
      # Adds error to end_local field

  """
  def validate_begin_before_end(changeset) do
    begin = get_field(changeset, :begin)
    end_ = get_field(changeset, :end)

    if begin != nil && end_ != nil && DateTime.compare(begin, end_) != :lt do
      add_error(changeset, :end_local, "Must be after begin.")
    else
      changeset
    end
  end

  @doc """
  Converts local datetime to UTC datetime.

  Takes a tuple of {from_field, to_field} and converts the value from the from_field
  to UTC timezone and puts it in the to_field.

  For multiple conversions, takes a list of tuples of {from_field, to_field} and converts each pair.

  ## Examples

      iex> changeset = %Ecto.Changeset{changes: %{begin_local: ~N[2025-03-14 16:12:00]}}
      iex> Changeset.fill_utc_dates(changeset, {:begin_local, :begin})
      # Puts converted UTC datetime in begin field

      iex> changeset = %Ecto.Changeset{changes: %{begin_local: ~N[2025-03-14 16:12:00], end_local: ~N[2025-03-14 17:12:00]}}
      iex> Changeset.fill_utc_dates(changeset, [ {:begin_local, :begin}, {:end_local, :end} ])
      # Puts converted UTC datetimes in begin and end fields

  """
  def fill_utc_dates(changeset, {from, to}) do
    local_date = get_field(changeset, from)

    utc_date =
      case(local_date) do
        nil ->
          nil

        date ->
          DateTime.from_naive!(date, DevRound.Formats.time_zone())
          |> DateTime.shift_zone!("Etc/UTC")
      end

    put_change(changeset, to, utc_date)
  end

  def fill_utc_dates(changeset, opts) do
    Enum.reduce(opts, changeset, fn opt, changeset -> fill_utc_dates(changeset, opt) end)
  end

  @doc """
  Generates a slug from date and title.

  Creates a slug in the format "YYYY-MM-DD-title" using the title and begin_local date.

  ## Examples

      iex> changeset = %Ecto.Changeset{changes: %{title: "My Event", begin_local: ~N[2025-03-14 16:12:00]}}
      iex> Changeset.generate_date_title_slug(changeset)
      # Puts slug "2025-03-14-my-event" in slug field

  """
  def generate_date_title_slug(changeset) do
    case get_field(changeset, :title) do
      nil ->
        changeset

      title ->
        case(get_field(changeset, :begin_local)) do
          nil ->
            changeset

          begin ->
            slug_data = "#{Calendar.strftime(begin, "%Y-%m-%d")}-#{title}"
            put_change(changeset, :slug, Slug.slugify(slug_data))
        end
    end
  end
end
