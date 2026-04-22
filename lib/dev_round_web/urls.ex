defmodule DevRoundWeb.Urls do
  @moduledoc """
  Central URL Definitions.
  """

  use DevRoundWeb, :verified_routes

  alias DevRound.Events.Event

  def event_slides_url(event, opts \\ [])

  def event_slides_url(%Event{slides_filename: nil}, _opts), do: nil

  def event_slides_url(%Event{slides_filename: filename} = event, opts) do
    if Keyword.get(opts, :download, false) do
      ~p"/events/#{event}/slides/#{filename}?download=1"
    else
      ~p"/events/#{event}/slides/#{filename}"
    end
  end
end
