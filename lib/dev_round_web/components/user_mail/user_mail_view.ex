defmodule DevRoundWeb.UserMailComponents do
  use DevRoundWeb, :html

  embed_templates("*.html", suffix: "_html")
end
