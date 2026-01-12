defmodule DevRoundWeb.PageController do
  use DevRoundWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
