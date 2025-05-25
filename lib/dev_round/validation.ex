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

end
