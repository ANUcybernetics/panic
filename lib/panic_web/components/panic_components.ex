defmodule PanicWeb.PanicComponents do
  @moduledoc """
  Provides Panic-specific UI components.

  Because this module imports the (template-provided) `PanicWeb.CoreComponents`,
  the main PanicWeb helpers have been modified to import _this_ module instead
  (to avoid circular dep issues).
  """
  use Phoenix.Component

  import PanicWeb.AutocompleteInput

  alias Panic.Engine.Invocation
  alias PanicWeb.NetworkLive.NetworkHelpers

  @doc """
  Renders a model box.

  Useful for displaying a representation of a model (e.g. in a "network list")
  component.
  """
  attr :model, :any, required: true, doc: "Panic.Model struct"

  slot :action, doc: "the slot for showing user actions in the model box"

  def model_box(assigns) do
    ~H"""
    <div class="size-16 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm">
      <div class={[
        "size-6 absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1/2 -z-10",
        io_colour_mapper(@model.input_type)
      ]}>
      </div>
      {@model.name}
      <div class={[
        "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
        io_colour_mapper(@model.output_type)
      ]}>
      </div>
      {render_slot(@action)}
    </div>
    """
  end

  @doc """
  Renders a list of models in a flexbox layout.

  ## Examples

      <.model_list models={@models} />
  """
  attr :models, :list, required: true, doc: "List of Panic.Model structs"

  attr :phx_target, :any, default: nil

  def model_list(assigns) do
    ~H"""
    <div class="flex items-center flex-wrap gap-6">
      <div class="size-8 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm">
        T
        <div class={[
          "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
          io_colour_mapper(:text)
        ]}>
        </div>
      </div>
      <%= for {model, index} <- Enum.with_index(@models) do %>
        <.model_box model={model}>
          <:action>
            <button
              phx-click="remove_model"
              phx-value-index={index}
              phx-target={@phx_target}
              class="absolute size-4 top-0 right-0 text-xs text-gray-500 hover:text-gray-700"
            >
              ×
            </button>
          </:action>
        </.model_box>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a list of models with integrated add functionality.

  ## Examples

      <.model_list_with_add models={@models} model_options={@model_options} phx_target={@myself} />
  """
  attr :models, :list, required: true, doc: "List of Panic.Model structs"
  attr :model_options, :list, required: true, doc: "List of model options for autocomplete"
  attr :phx_target, :any, default: nil

  def model_list_with_add(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Model list -->
      <div class="flex items-center flex-wrap gap-6">
        <div class="size-8 rounded-md grid place-content-center text-center text-xs relative bg-zinc-600 shadow-sm">
          T
          <div class={[
            "size-6 absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 -z-10",
            io_colour_mapper(:text)
          ]}>
          </div>
        </div>
        <%= for {model, index} <- Enum.with_index(@models) do %>
          <.model_box model={model}>
            <:action>
              <button
                phx-click="remove_model"
                phx-value-index={index}
                phx-target={@phx_target}
                class="absolute size-4 top-0 right-0 text-xs text-gray-500 hover:text-gray-700"
              >
                ×
              </button>
            </:action>
          </.model_box>
        <% end %>
      </div>

    <!-- Autocomplete input -->
      <div class="autocomplete-wrapper [&_input]:bg-zinc-800 [&_input]:border [&_input]:border-zinc-600 [&_input]:text-zinc-100 [&_input]:placeholder-zinc-500 [&_input]:text-sm [&_input]:rounded-md [&_input]:p-3 [&_input]:w-full [&_input]:transition-all [&_input]:duration-150 [&_input]:ease-in-out [&_input]:appearance-none [&_input:focus]:outline-none [&_input:focus]:border-violet-500 [&_input:focus]:ring-3 [&_input:focus]:ring-violet-500/10">
        <.autocomplete_input
          id="network_model_autocomplete"
          name="model"
          options={@model_options}
          value=""
          display_value="Add model..."
          min_length={1}
        />
      </div>
    </div>
    """
  end

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
  slot :input, doc: "Optional input to render in the top left corner"

  def invocation_container(assigns) do
    ~H"""
    <div id={@id} class="relative aspect-video overflow-hidden">
      {render_slot(@inner_block)}
      <%= if @input && false do %>
        <div class="absolute top-0 left-0 aspect-video h-1/3">
          {render_slot(@input)}
        </div>
      <% end %>
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

  def invocation(%{invocation: %Invocation{state: :invoking}} = assigns) do
    ~H"""
    <.invocation_container id={@id}>
      <div class="size-full grid place-items-center animate-breathe bg-rose-500 @container">
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
      <.invocation_slot id={@id} type={@model.output_type} value={@invocation.output} />
      <:input>
        <.invocation_slot id={"#{@id}-input"} type={@model.input_type} value={@invocation.input} />
      </:input>
    </.invocation_container>
    """
  end

  attr :type, :atom, required: true, doc: "the type (modality) of the invocation input or output"
  attr :value, :string, required: true, doc: "the value of the invocation input or output"
  attr :id, :string, required: true

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
    <img class="object-cover w-full" src={@value} />
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

  # def invocation_slot(%{type: :audio} = assigns) do
  #   ~H"""
  #   <div class="relative">
  #     <audio autoplay loop controls={true} src={@value} class="absolute top-0 left-0" />
  #     <img
  #       class="object-cover w-full"
  #       src="https://fly.storage.tigris.dev/panic-invocation-outputs/audio-waveform-image.webp"
  #     />
  #   </div>
  #   """
  # end

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
  Renders a modal containing a QR code.
  """
  attr :text, :string, required: true, doc: "the text data to encode in the QR code"
  attr :title, :string, default: "wtf is this?", doc: "the title to display above the QR code"

  def qr_code(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <h2 class="text-4xl font-semibold mb-8">{@title}</h2>
      <div>
        {@text
        |> QRCode.create(:high)
        |> QRCode.render(:svg, %QRCode.Render.SvgSettings{
          qrcode_color: {216, 180, 254},
          background_color: {24, 24, 27}
        })
        # unwrap the tuple
        |> elem(1)
        |> Phoenix.HTML.raw()}
      </div>
    </div>
    """
  end

  def panic_button(assigns) do
    ~H"""
    <div class={[
      "rounded-full grid place-items-center animate-breathe bg-rose-500",
      @class
    ]}>
      <.shadowed_text>PANIC!</.shadowed_text>
    </div>
    """
  end
end
