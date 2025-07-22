defmodule DevRoundWeb.PageController do
  use DevRoundWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/events")
  end
end
