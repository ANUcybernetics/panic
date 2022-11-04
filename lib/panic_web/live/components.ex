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
    <img class="w-full object-cover" src={@run.output} />
    """
  end

  def audio_run(assigns) do
    ~H"""
    <audio autoplay controls={false} src={local_or_remote_url(@socket, @run.output)} />
    <HeroiconsV1.Outline.volume_up class="w-12 h-12 mx-auto" />
    """
  end

  def run(assigns) do
    ~H"""
    <div class="relative block w-full text-center text-gray-800 bg-gray-200 shadow-lg dark:bg-gray-800 hover:bg-gray-300 dark:text-gray-400 dark:group-hover:text-gray-100">
      <div class="aspect-w-16 aspect-h-9 overflow-hidden">
        <div class="absolute inset-0 grid place-items-center">
          <%= if @run do %>
            <%= case @run.status do %>
              <% :created -> %>
                <HeroiconsV1.Outline.minus_circle class="w-12 h-12 mx-auto" />
              <% :running -> %>
                <.spinner class="mx-auto" size="md" />
              <% :succeeded -> %>
                <%= case Models.model_io(@run.model) do %>
                  <% {_, :text} -> %>
                    <.vestaboard_run run={@run} board_name={:panic_1} />
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
          <% else %>
            <div class="text-gray-400 italic">blank</div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def slots_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 md:grid-cols-3">
      <%= for {run, _idx} <- Enum.with_index(@slots) do %>
        <.run run={run} socket={@socket} />
      <% end %>
    </div>
    """
  end

  def vestaboard_simulator(assigns) do
    {:ok, result} = Vestaboard.send_text(assigns.board_name, assigns.run.output)

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
