defmodule DevRoundWeb.LangIconController do
  use DevRoundWeb, :controller

  alias DevRound.Events

  def show(conn, %{"file_name" => file_name}) do
    {:ok, icon} = read_icon_data(file_name)
    send_icon_data(conn, icon)
  end

  defp read_icon_data(file_name) do
    IO.puts(:code.priv_dir(:dev_round))
    src_path = Path.join([:code.priv_dir(:dev_round), Events.lang_icon_dir(), file_name])
    File.read(src_path)
  end

  defp send_icon_data(conn, icon) when not is_nil(icon) do
    content_type = detect_content_type(icon)

    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("cache-control", "private, max-age=31536000, immutable")
    |> send_resp(200, icon)
  end

  defp send_icon_data(conn, nil) do
    conn
    |> send_resp(404, "Icon not found")
  end

  # Detect content type from binary data
  defp detect_content_type(<<0x89, 0x50, 0x4E, 0x47, _rest::binary>>), do: "image/png"
  defp detect_content_type(<<"<?xml", _rest::binary>>), do: "image/svg+xml"
  defp detect_content_type(<<"<svg", _rest::binary>>), do: "image/svg+xml"
  defp detect_content_type(_), do: "application/octet-stream"
end
