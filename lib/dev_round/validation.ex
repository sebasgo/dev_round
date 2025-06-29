defmodule DevRound.Validation do

  import Ecto.Changeset

  def validate_option_selected(changeset, [field | remaining]) do
    options = get_field(changeset, field)
    new_changeset = if is_nil(options) || Enum.empty?(options) do
      add_error(changeset, field, "Required.")
    else
      changeset
    end
    validate_option_selected(new_changeset, remaining)
  end

  def validate_option_selected(changeset, []), do: changeset

  def validate_experience_level(changeset) do
    changeset
    |> validate_number(:experience_level, greater_than_or_equal_to: 0, less_than: 10, message: "Must be between 0 and 9 inclusive.")
  end

end
