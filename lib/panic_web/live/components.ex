defmodule PanicWeb.Live.Components do
  use PanicWeb, :component

  @doc """
  A live "grid" of run cards
  """

  def run_widget(assigns) do
    ~H"""
    <div class="relative block w-full text-center text-gray-800 bg-gray-200 shadow-lg dark:bg-gray-800 hover:bg-gray-300 dark:text-gray-400 dark:group-hover:text-gray-100">
      <div class="h-48 grid place-items-center overflow-hidden">
        <%= if @run do %>
          <%= case @run.status do %>
            <% :created -> %>
              <HeroiconsV1.Outline.minus_circle class="w-12 h-12 mx-auto" />
            <% :running -> %>
              <.spinner class="mx-auto" size="md" />
            <% :succeeded -> %>
              <%= case Models.model_io(@run.model) do %>
                <% {_, :text} -> %>
                  <div class="p-2 text-md text-left">
                    <%= for line <- String.split(@run.output, "\n\n") do %>
                      <%= unless line == "" do %>
                        <p><%= line %></p>
                      <% end %>
                    <% end %>
                  </div>
                <% {_, :image} -> %>
                  <img class="w-full object-cover" src={@run.output} />
                <% {_, :audio} -> %>
                  <audio autoplay controls={false} src={local_or_remote_url(@socket, @run.output)} />
                  <HeroiconsV1.Outline.volume_up class="w-12 h-12 mx-auto" />
              <% end %>
            <% :failed -> %>
              <HeroiconsV1.Outline.x_circle class="w-12 h-12 mx-auto" />
          <% end %>
          <div class="absolute left-2 -bottom-6">
            <%= @run.model |> String.split(~r/[:\/]/) |> List.last() %>
          </div>
        <% else %>
          <span class="text-gray-400 italic">blank</span>
        <% end %>
      </div>
    </div>
    """
  end

  def vestaboard_simulator(assigns) do
    board_id = "ba16996e-154f-4f31-83b7-ae0a8f13ecaf" # Panic 1

    ~H"""
    <iframe src="https://simulator.vestaboard.com/?boardId={@board_id}" width="710" height="404.7" scrolling="no" style="border: none"></iframe>
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
