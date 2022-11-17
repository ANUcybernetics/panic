defmodule PanicWeb.Live.Components do
  use PanicWeb, :component
  alias Panic.Models
  alias Panic.Models.Platforms.Vestaboard

  def text_run(assigns) do
    ~H"""
    <div class="p-4 text-md text-left">
      <%= for line <- String.split(@run.output, "\n\n") do %>
        <%= unless line == "" do %>
          <p><%= line %></p>
        <% end %>
      <% end %>
    </div>
    """
  end

  def vestaboard_run(assigns) do
    ~H"""
    <.vestaboard_simulator run={@run} board_name={@board_name} />
    """
  end

  def image_run(assigns) do
    ~H"""
    <div class="relative w-full">
      <img class="w-full object-cover" src={@run.output} />
      <span class="absolute top-2 right-2 text-4xl text-gray-300 text-right">
        <%= @run.model %>
      </span>
      <span class="absolute left-2 bottom-2 text-6xl text-gray-100 text-left"><%= @run.input %></span>
    </div>
    """
  end

  def audio_run(assigns) do
    ~H"""
    <audio autoplay controls={false} src={@run.output} />
    <HeroiconsV1.Outline.volume_up class="w-12 h-12 mx-auto" />
    """
  end

  def run(%{run: nil} = assigns) do
    ~H"""
    <div class="aspect-w-16 aspect-h-9 overflow-hidden relative block w-full text-center text-gray-200 bg-gray-50 shadow-lg">
      <div class="grid place-items-center">BLANK</div>
    </div>
    """
  end

  def run(assigns) do
    ~H"""
    <div class="aspect-w-16 aspect-h-9 overflow-hidden relative block w-full text-center text-gray-800 bg-gray-200 shadow-lg dark:bg-gray-800 hover:bg-gray-300 dark:text-gray-400 dark:group-hover:text-gray-100">
      <div class="absolute inset-0 grid place-items-center">
        <%= case @run.status do %>
          <% :created -> %>
            <HeroiconsV1.Outline.minus_circle class="w-12 h-12 mx-auto" />
          <% :running -> %>
            <.spinner class="mx-auto" size="md" />
          <% :succeeded -> %>
            <%= case Models.model_io(@run.model) do %>
              <% {_, :text} -> %>
                <.text_run run={@run} />
              <% {_, :image} -> %>
                <.image_run run={@run} />
              <% {_, :audio} -> %>
                <.audio_run run={@run} />
            <% end %>
          <% :failed -> %>
            <HeroiconsV1.Outline.x_circle class="w-12 h-12 mx-auto" />
        <% end %>
        <div class="absolute left-2 -bottom-6">
          <%= @run.model |> String.split(~r/[:\/]/) |> List.last() %>
        </div>
      </div>
    </div>
    """
  end

  def slots_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 md:grid-cols-3">
      <%= for {run, _idx} <- Enum.with_index(@slots) do %>
        <.run run={run} />
      <% end %>
    </div>
    """
  end

  def vestaboard_simulator(assigns) do
    {:ok, _result} = Vestaboard.send_text(assigns.board_name, assigns.run.output)

    ~H"""
    <iframe
      src="https://simulator.vestaboard.com/?boardId={Vestaboard.board_id(@board_name)}"
      width="710"
      height="404.7"
      scrolling="no"
      style="absolute border-none insert-0"
    >
    </iframe>
    """
  end

  def local_or_remote_url(socket, url) do
    if String.match?(url, ~r/https?:\/\//) do
      url
    else
      Routes.static_path(socket, "/model_outputs/" <> Path.basename(url))
    end
  end
end
