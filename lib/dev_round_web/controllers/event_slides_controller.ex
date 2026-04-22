defmodule DevRoundWeb.EventSlidesController do
  use DevRoundWeb, :controller

  alias DevRoundWeb.NotFoundError
  alias DevRound.Events

  def show(conn, %{"slug" => slug} = params) do
    event = Events.get_event!(slug)

    case event.slides_filename do
      nil ->
        raise NotFoundError, "event #{event.id} has no slides"

      file_name ->
        {:ok, data} = read_data(file_name)

        if Map.get(params, "download") == "1" do
          conn =
            put_resp_header(conn, "content-disposition", "attachment; filename=\"#{slug}.pdf\"")

          send_data(conn, data)
        else
          send_data(conn, data)
        end
    end
  end

  defp read_data(file_name) do
    src_path = Path.join([:code.priv_dir(:dev_round), Events.event_slides_dir(), file_name])
    File.read(src_path)
  end

  defp send_data(conn, data) do
    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
    |> send_resp(200, data)
  end
end
