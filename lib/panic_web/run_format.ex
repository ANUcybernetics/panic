defmodule PanicWeb.RunFormat do
  @moduledoc """
  Formats a run summary (see `PanicWeb.NetworkLive.RunSummary`) for displays:
  its elapsed time and estimated footprint (see `Panic.Engine.Footprint`),
  including an everyday comparison for its energy:

  - an LED bulb, which draws about 10 W (a 60 W-equivalent bulb draws 8--10 W)
  - a phone charge, about 15 Wh (a smartphone battery holds 12--20 Wh, and
    charging loses some)
  - boiling a litre of water in a kettle, about 100 Wh (heating it from 20 °C
    takes 93 Wh, plus what the kettle loses)
  """

  @led_bulb_w 10
  @phone_charge_wh 15
  @kettle_wh 100

  @doc """
  The time since `started_at`, to the minute (it's rendered on the server, so
  seconds would sit frozen between updates).
  """
  def elapsed(started_at, now \\ DateTime.utc_now()) do
    case DateTime.diff(now, started_at, :second) do
      seconds when seconds < 60 -> "under a minute"
      seconds -> duration(seconds, :minute)
    end
  end

  @doc """
  A duration of `seconds` in short form, leaving out leading zero units (the
  browser countdowns use the same form, from `assets/js/duration.js`).

      iex> PanicWeb.RunFormat.duration(45)
      "45s"
      iex> PanicWeb.RunFormat.duration(125)
      "2m 05s"
      iex> PanicWeb.RunFormat.duration(20_542)
      "5h 42m 22s"
      iex> PanicWeb.RunFormat.duration(3_725, :minute)
      "1h 02m"
  """
  def duration(seconds, precision \\ :second)

  def duration(seconds, :second) do
    case {div(seconds, 3600), div(rem(seconds, 3600), 60), rem(seconds, 60)} do
      {0, 0, s} -> "#{s}s"
      {0, m, s} -> "#{m}m #{pad(s)}s"
      {h, m, s} -> "#{h}h #{pad(m)}m #{pad(s)}s"
    end
  end

  def duration(seconds, :minute) do
    case {div(seconds, 3600), div(rem(seconds, 3600), 60)} do
      {0, m} -> "#{m}m"
      {h, m} -> "#{h}h #{pad(m)}m"
    end
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc "Energy in watt-hours, in Wh or kWh."
  def energy(wh) when wh >= 1000, do: "#{Float.round(wh / 1000, 1)} kWh"
  def energy(wh) when wh >= 10, do: "#{round(wh)} Wh"
  def energy(wh), do: "#{Float.round(wh * 1.0, 1)} Wh"

  @doc "A cost in US dollars."
  def cost(usd) when usd > 0 and usd < 0.01, do: "< US$0.01"
  def cost(usd), do: "US$#{:erlang.float_to_binary(usd * 1.0, decimals: 2)}"

  @doc """
  An everyday use of about `wh` watt-hours, picked so its count reads
  naturally, or nil for no energy.
  """
  def everyday(wh) when wh <= 0, do: nil

  def everyday(wh) when wh < @phone_charge_wh do
    case round(wh / @led_bulb_w * 60) do
      0 -> "a few seconds of an LED bulb"
      1 -> "a minute of an LED bulb"
      minutes -> "#{minutes} minutes of an LED bulb"
    end
  end

  def everyday(wh) when wh < 5 * @kettle_wh do
    case round(wh / @phone_charge_wh) do
      1 -> "a phone charge"
      charges -> "#{charges} phone charges"
    end
  end

  def everyday(wh), do: "#{round(wh / @kettle_wh)} kettles boiled"
end
