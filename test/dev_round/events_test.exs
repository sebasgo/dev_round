defmodule DevRound.Events.LangTest do
  use DevRound.DataCase

  alias DevRound.Events
  alias DevRound.Events.Lang

  import DevRound.EventsFixtures

  describe "change_lang/2" do
    test "returns a changeset with valid data" do
      attrs = %{name: "Elixir", icon_path: "elixir.png"}
      changeset = Events.change_lang(%Lang{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :name) == "Elixir"
      assert Ecto.Changeset.get_field(changeset, :icon_path) == "elixir.png"
    end

    test "returns an invalid changeset with missing name" do
      attrs = %{icon_path: "elixir.png"}
      changeset = Events.change_lang(%Lang{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset with missing icon_path" do
      attrs = %{name: "Elixir"}
      changeset = Events.change_lang(%Lang{}, attrs)

      refute changeset.valid?
      assert %{icon_path: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset with empty icon_path" do
      attrs = %{name: "Elixir", icon_path: ""}
      changeset = Events.change_lang(%Lang{}, attrs)

      refute changeset.valid?
      assert %{icon_path: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset with 'too_many_files' icon_path" do
      attrs = %{name: "Elixir", icon_path: "too_many_files"}
      changeset = Events.change_lang(%Lang{}, attrs)

      refute changeset.valid?
      assert %{icon_path: ["Only one icon is allowed."]} = errors_on(changeset)
    end
  end

  describe "create_lang/1" do
    test "creates a lang with valid data" do
      attrs = %{name: "Python", icon_path: "python.svg"}

      assert {:ok, %Lang{} = lang} = Events.create_lang(attrs)
      assert lang.name == "Python"
      assert lang.icon_path == "python.svg"
    end

    test "does not create a lang with invalid data" do
      attrs = %{name: "Python"}

      assert {:error, %Ecto.Changeset{}} = Events.create_lang(attrs)
    end
  end

  describe "get_lang_by_name/1" do
    test "returns lang when name exists" do
      lang = lang_fixture(%{name: "C++", icon_path: "cpp.svg"})

      assert %Lang{} = Events.get_lang_by_name("C++")
      assert Events.get_lang_by_name("C++").id == lang.id
    end

    test "returns nil when name does not exist" do
      assert is_nil(Events.get_lang_by_name("NonExistent"))
    end
  end
end
