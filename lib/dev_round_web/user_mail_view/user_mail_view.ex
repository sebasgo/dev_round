defmodule DevRoundWeb.UserMailView do
  #import Phoenix.Template, only: [embed_templates: 2]
  use DevRoundWeb, :html

  embed_templates("*.html", suffix: "_html")
end
