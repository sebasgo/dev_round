defmodule DevRoundWeb.UserMail do
  import Swoosh.Email
  alias DevRoundWeb.UserMailView

  def confirm_registration(user, event) do
    html = UserMailView.confirm_registration_html(%{user: user, event: event}) |> heex_to_html()
    new()
    |> to({user.full_name, user.email})
    |> from(Application.get_env(:dev_round, :mail_from))
    |> from({"DevRound", "devround@localhost"})
    |> subject("[DevRound] Registration Confirmed: #{event.title}")
    |> html_body(html)
    |> attachment(Swoosh.Attachment.new(
      {:data, generate_ics(event)},
      filename: "invite.ics",
      content_type: "text/calendar"
    ))
  end

  defp heex_to_html(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp generate_ics(event) do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//DevRound//EN
    BEGIN:VEVENT
    UID:#{UUID.uuid4()}
    DTSTAMP:#{format_datetime(DateTime.utc_now(:second, Calendar.ISO))}
    DTSTART:#{format_datetime(event.begin)}
    DTEND:#{format_datetime(event.end)}
    SUMMARY:#{escape_text(event.title)}
    LOCATION:#{escape_text(event.location)}
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y%m%dT%H%M%SZ")
  end

  defp escape_text(text) when is_binary(text) do
    text
    # First escape backslashes (must be done first to avoid double-escaping)
    |> String.replace("\\", "\\\\")
    # Then escape commas
    |> String.replace(",", "\\,")
    # Then escape semicolons
    |> String.replace(";", "\\;")
    # Handle newlines - convert actual newlines to escaped newlines
    |> String.replace("\n", "\\\n")  # First handle literal \n in the string
    |> String.replace("\r\n", "\\\n")  # Windows line endings
    |> String.replace("\r", "\\\n")  # Mac line endings
    |> String.replace("\n", "\\\n")  # Unix line endings
  end

end
