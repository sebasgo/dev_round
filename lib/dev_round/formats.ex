defmodule DevRound.Formats do

  def format_datetime(dt) do
    Calendar.strftime(dt, "%d.%m.%Y %H:%M")
  end

  def format_date(dt) do
    Calendar.strftime(dt, "%d.%m.%Y")
  end

  def format_time(dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  def format_datetime_range(dt1, dt2) do
    if Date.compare(dt1, dt2) == :eq do
      "#{format_date(dt1)} #{format_time(dt1)} – #{format_time(dt2)}"
    else
      "#{format_datetime(dt1)} – #{format_datetime(dt2)}"
    end
  end

  def time_zone, do: Application.get_env(:dev_round, :time_zone)

end
