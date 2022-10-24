defmodule PetalFramework.Components.LocalTime do
  use Phoenix.Component

  @default_options %{dateStyle: "medium", timeStyle: "medium"}

  @doc """
  Usage:
      <.local_time date={Timex.now()} id="time" />
      => Aug 10, 2022, 2:09:46 PM

      <.local_time class="block mt-5" date={Timex.now()} id="time" options={%{dateStyle: "short"}} />
      => 8/10/22

      <.local_time date={Timex.now() |> Timex.shift(days: 40)} options={%{relative: true}} />
      => in 1 month

  Basic options:
  %{
    dateStyle: "short" | "medium" | "long" | "full",
    timeStyle: "short" | "medium" | "long" | "full",
    relative: true | false,
  }
  See more fine grained options: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
  """

  attr :date, :any, doc: "A date-like type"
  attr :id, :string
  attr :options, :map, doc: "See function comment for examples"
  attr :rest, :global

  def local_time(assigns) do
    assigns =
      assigns
      |> assign_new(:options, fn -> @default_options end)

    ~H"""
    <time phx-hook="LocalTimeHook" {@rest} class="invisible" data-options={Jason.encode!(@options)}>
      <%= @date %>
    </time>
    """
  end
end
