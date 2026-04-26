defmodule DevRoundWeb.Admin.HomeController do
  use DevRoundWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/admin/events")
  end
end
