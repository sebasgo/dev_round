defmodule DevRoundWeb.ErrorHTMLTest do
  use DevRoundWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(DevRoundWeb.ErrorHTML, "404", "html", []) =~ "DevRound Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(DevRoundWeb.ErrorHTML, "500", "html", []) =~ "Internal DevRound Error"
  end
end
