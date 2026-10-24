defmodule DevRound.Markdown do
  @moduledoc """
  Centralized markdown to HTML rendering.

  This module is the single source of truth for how markdown is rendered. It is
  used both by the public event pages (`DevRoundWeb.CoreComponents.markdown/1`)
  and by the admin markdown editor preview, so both are guaranteed to render
  identically.
  """

  @extensions [
    superscript: true,
    subscript: true,
    footnotes: true,
    table: true,
    strikethrough: true,
    autolink: true,
    tasklist: true,
    alerts: true
  ]

  @doc """
  Renders a markdown string to safe HTML.

  `nil` is treated as an empty string.
  """
  @spec to_html(String.t() | nil) :: Phoenix.HTML.safe()
  def to_html(markdown) do
    markdown
    |> to_string_safe()
    |> String.trim()
    |> MDEx.to_html!(extension: @extensions)
    |> Phoenix.HTML.raw()
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(markdown), do: markdown
end
