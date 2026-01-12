defmodule DevRoundWeb.ErrorJSONTest do
  use DevRoundWeb.ConnCase, async: true

  test "renders 404" do
    assert DevRoundWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert DevRoundWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
