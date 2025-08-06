defmodule DevRound.Changeset do
  import Ecto.Changeset

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

  def validate_experience_level(changeset) do
    changeset
    |> validate_number(:experience_level,
      greater_than_or_equal_to: 0,
      less_than: 10,
      message: "Must be between 0 and 9 inclusive."
    )
  end

  def validate_begin_before_end(changeset) do
    begin = get_field(changeset, :begin)
    end_ = get_field(changeset, :end)

    if begin != nil && end_ != nil && DateTime.compare(begin, end_) != :lt do
      add_error(changeset, :end_local, "Must be after begin.")
    else
      changeset
    end
  end

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
