defmodule DevRoundWeb.UserMailComponents do
  @moduledoc """
  HTML components for user mail templates.

  Provides HTML templates for email notifications related to user
  registration and authentication workflows.
  """

  use DevRoundWeb, :html

  embed_templates("*.html", suffix: "_html")
end
