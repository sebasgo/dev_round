defmodule DevRoundWeb.EventSlidesController do
  use DevRoundWeb, :controller

  alias DevRound.Events

  def show(conn, %{"file_name" => file_name}) do
    {:ok, data} = read_data(file_name)
    send_data(conn, data)
  end

  defp read_data(file_name) do
    IO.puts(:code.priv_dir(:dev_round))
    IO.puts(Events.event_slides_dir())
    src_path = Path.join([:code.priv_dir(:dev_round), Events.event_slides_dir(), file_name])
    IO.inspect(src_path, label: "PATH")
    File.read(src_path)
  end

  defp send_data(conn, data) do
    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
    |> send_resp(200, data)
  end
end
