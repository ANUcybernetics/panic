defmodule PanicWeb.PanicComponents do
  @moduledoc """
  Provides Panic-specific UI components.

  Because this module imports the (template-provided) `PanicWeb.CoreComponents`,
  the main PanicWeb helpers have been modified to import _this_ module instead
  (to avoid circular dep issues).
  """
  use Phoenix.Component

  alias Panic.Engine.Invocation
  alias PanicWeb.NetworkLive.NetworkHelpers

  defp io_colour_mapper(type) do
    case type do
      :text -> "bg-orange-500"
      :image -> "bg-blue-400"
      :audio -> "bg-emerald-800"
    end
  end

  ## display grid/screens

  attr :invocations, :any, required: true, doc: "invocations stream"

  attr :display, :any,
    required: true,
    doc: "the grid tuple: {:grid, row, col} or {:single, offset, stride, show_invoking}"

  def display(assigns) do
    ~H"""
    <div
      id="current-inovocations"
      class={"grid gap-4 grid-cols-#{num_cols(@display)}"}
      phx-update="stream"
    >
      <div id="display-info" class="p-4 text-2xl text-purple-300/50 only:block hidden">
        <span class="flex items-center gap-4">
          <span>{"#{elem(@display, 1)}/#{elem(@display, 2)}"}</span>
          <span class="text-lg">
            <%= case @display do %>
              <% {:grid, _, _} -> %>
                <span title="Grid view">⊞</span>
              <% {:single, _, _, _} -> %>
                <span title="Single view">□</span>
            <% end %>
          </span>
        </span>
      </div>
      <.invocation
        :for={{id, invocation} <- @invocations}
        id={id}
        invocation={invocation}
        model={NetworkHelpers.get_model_or_placeholder(invocation.model)}
      />
    </div>
    """
  end

  defp num_cols({:grid, _rows, cols}), do: cols
  defp num_cols({:single, _, _, _}), do: 1

  # individual components

  attr :id, :string, required: true
  slot :inner_block, required: true

  def invocation_container(assigns) do
    ~H"""
    <div id={@id} class="relative aspect-video overflow-hidden">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :invocation, :any, required: true, doc: "Panic.Engine.Invocation struct"
  attr :model, :any, required: true, doc: "Panic.Model struct"
  attr :id, :string, required: true

  def invocation(%{invocation: %Invocation{state: :failed}} = assigns) do
    ~H"""
    <.invocation_container id={@id}>
      <div class="size-full grid place-items-center bg-rose-950"></div>
    </.invocation_container>
    """
  end

  # a genesis invocation is shown while it waits to start, so the run appears straight away
  def invocation(%{invocation: %Invocation{state: state}} = assigns) when state in [:ready, :invoking] do
    ~H"""
    <.invocation_container id={@id}>
      <div class="size-full grid place-items-center motion-safe:animate-breathe bg-rose-500 @container">
        <div class="text-[25cqw]">
          <.shadowed_text>P!</.shadowed_text>
        </div>
      </div>
    </.invocation_container>
    """
  end

  def invocation(assigns) do
    ~H"""
    <.invocation_container id={@id}>
      <.invocation_slot
        id={@id}
        type={@model.output_type}
        value={@invocation.output}
        alt={if @model.input_type == :text, do: @invocation.input, else: ""}
      />
    </.invocation_container>
    """
  end

  attr :type, :atom, required: true, doc: "the type (modality) of the invocation input or output"
  attr :value, :string, required: true, doc: "the value of the invocation input or output"
  attr :id, :string, required: true
  attr :alt, :string, default: "", doc: "alt text for an image (the prompt, when it was text)"

  def invocation_slot(%{type: :text} = assigns) do
    assigns = assign(assigns, :parsed_content, parse_text_content(assigns.value))

    ~H"""
    <div
      id={"#{@id}-text"}
      class="size-full grid place-items-center p-2 bg-zinc-800 text-left @container"
    >
      <div class="[text-shadow:2px_2px_0px_#581c87] text-left text-[8px] @[200px]:text-[10px] @[400px]:text-xs @[600px]:text-sm @[800px]:text-base">
        {@parsed_content}
      </div>
    </div>
    """
  end

  def invocation_slot(%{type: :image} = assigns) do
    ~H"""
    <img class="object-cover size-full" src={@value} alt={@alt} />
    """
  end

  def invocation_slot(%{type: :audio} = assigns) do
    ~H"""
    <div
      class={["relative size-full", io_colour_mapper(:audio)]}
      id={"#{@id}-audio-visualizer"}
      phx-hook="AudioVisualizer"
      data-audio-src={@value}
    >
      <div class="visualizer-container absolute inset-0"></div>
    </div>
    """
  end

  defp parse_text_content(text) when is_binary(text) and text != "" do
    case MDEx.to_html(text) do
      {:ok, html} -> Phoenix.HTML.raw(html)
      # Fallback to raw text if parsing fails
      {:error, _} -> text
    end
  end

  defp parse_text_content(_), do: ""

  # #581c87 is purple-900
  def shadowed_text(assigns) do
    ~H"""
    <p class="[text-shadow:2px_2px_0px_#581c87]">
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a QR code with a title, for showing in a modal.
  """
  attr :text, :string, required: true, doc: "the text data to encode in the QR code"
  attr :title, :string, default: "wtf is this?", doc: "the title to display above the QR code"

  def qr_code(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <h2 class="mb-6 text-2xl font-semibold sm:text-4xl">{@title}</h2>
      <div class="w-full max-w-md [&_svg]:h-auto [&_svg]:w-full">
        {qr_svg(@text, {216, 180, 254}, {24, 24, 27})}
      </div>
    </div>
    """
  end

  @doc """
  Renders the anonymous terminal's QR code in the bottom right of a display,
  where it covers the least of an image: dark on light, so phones read it
  even when it's small. With a run `summary`, a heads-up display of the run
  sits beside it on frosted glass, quiet enough to leave the image the focus
  and the QR code its light margin.
  """
  attr :url, :string, required: true
  attr :summary, :any, default: nil, doc: "a `PanicWeb.NetworkLive.RunSummary`, or nil when idle"

  def terminal_qr(assigns) do
    ~H"""
    <aside
      aria-label="Prompt this network"
      class="fixed right-[2vmin] bottom-[2vmin] z-10 flex items-stretch overflow-hidden rounded-[0.8vmin] shadow-[0_0_2vmin_rgb(0_0_0/0.5)]"
    >
      <div
        :if={@summary}
        id="run-hud"
        class="flex w-[28vmin] flex-col justify-between gap-[0.8vmin] bg-zinc-950/55 px-[1.4vmin] py-[1.2vmin] text-right font-mono text-[1.25vmin] leading-snug text-zinc-400 backdrop-blur-md"
      >
        <p class="line-clamp-3 text-zinc-100">“{@summary.prompt}”</p>
        <.run_stats
          summary={@summary}
          class="flex flex-col gap-[0.2vmin] [&_dd]:inline [&_dd]:text-zinc-100 [&_dt]:inline [&_dt]:after:content-['_']"
        />
      </div>
      <div
        id="terminal-qr"
        data-url={@url}
        class="w-[16vmin] bg-zinc-50 p-[0.6vmin] text-center text-[1.3vmin] leading-tight text-zinc-600 [&_svg]:h-auto [&_svg]:w-full"
      >
        {qr_svg(@url, {24, 24, 27}, {250, 250, 250})}
        <span class="block pb-[0.2vmin]">scan to prompt</span>
      </div>
    </aside>
    """
  end

  @doc """
  A run's vital signs (see `PanicWeb.NetworkLive.RunSummary`) as a list of
  terms, laid out and styled by `class`. Cost is only for signed-in viewers.
  """
  attr :summary, :any, required: true
  attr :show_cost?, :boolean, default: false
  attr :class, :any, default: nil

  def run_stats(assigns) do
    ~H"""
    <dl class={@class}>
      <div>
        <dt>invocation</dt>
        <dd id="run-stats-sequence" class="tabular-nums">{@summary.sequence_number}</dd>
      </div>
      <div>
        <dt>running</dt>
        <dd id="run-stats-elapsed">{PanicWeb.RunFormat.elapsed(@summary.started_at)}</dd>
      </div>
      <div class="truncate">
        <dt>now</dt>
        <dd id="run-stats-model">{@summary.model}</dd>
      </div>
      <div>
        <dt>energy</dt>
        <dd id="run-stats-energy">≈ {PanicWeb.RunFormat.energy(@summary.energy_wh)}</dd>
      </div>
      <div :if={PanicWeb.RunFormat.everyday(@summary.energy_wh)}>
        <dt class="sr-only">about the same as</dt>
        <dd id="run-stats-everyday">about {PanicWeb.RunFormat.everyday(@summary.energy_wh)}</dd>
      </div>
      <div :if={@show_cost?}>
        <dt>cost</dt>
        <dd id="run-stats-cost">≈ {PanicWeb.RunFormat.cost(@summary.cost_usd)}</dd>
      </div>
    </dl>
    """
  end

  defp qr_svg(text, colour, background) do
    {:ok, svg} =
      text
      |> QRCode.create(:medium)
      |> QRCode.render(:svg, %QRCode.Render.SvgSettings{
        qrcode_color: colour,
        background_color: background
      })

    # the SVG has a fixed size and no viewBox, so add one to let CSS size it;
    # it draws each module as a rect, and crispEdges stops anti-aliasing
    # leaving seams between them when it's scaled (which stops it scanning)
    svg
    |> String.replace(
      ~r/<svg width="(\d+)" height="(\d+)"/,
      ~S(<svg viewBox="0 0 \1 \2" shape-rendering="crispEdges"),
      global: false
    )
    |> Phoenix.HTML.raw()
  end

  def panic_button(assigns) do
    ~H"""
    <div class={[
      "rounded-full grid place-items-center motion-safe:animate-breathe bg-rose-500",
      @class
    ]}>
      <.shadowed_text>PANIC!</.shadowed_text>
    </div>
    """
  end
end
