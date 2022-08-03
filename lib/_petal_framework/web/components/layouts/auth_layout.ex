defmodule PetalFramework.Components.AuthLayout do
  use Phoenix.Component
  use PetalComponents

  # prop title, :string
  # slot default
  # slot top_links
  # slot bottom_links
  # slot logo
  def auth_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:top_links, fn -> [] end)
      |> assign_new(:bottom_links, fn -> [] end)
      |> assign_new(:home_page, fn -> "/" end)

    ~H"""
    <div class="fixed w-full h-full overflow-y-scroll bg-gray-100 dark:bg-gray-900">
      <div class="flex flex-col justify-center py-12 sm:px-6 lg:px-8">
        <div class="text-center sm:mx-auto sm:w-full sm:max-w-md">
          <div class="flex justify-center mb-10">
            <.link to={@home_page}>
              <%= render_slot(@logo) %>
            </.link>
          </div>

          <.h2>
            <%= @title %>
          </.h2>

          <%= if @top_links do %>
            <.p>
              <%= render_slot(@top_links) %>
            </.p>
          <% end %>
        </div>
      </div>

      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <div class="px-4 py-8 bg-white shadow sm:rounded-lg sm:px-10 dark:bg-gray-800">
          <%= render_slot(@inner_block) %>
        </div>

        <%= if @bottom_links do %>
          <div class="mt-5 text-center">
            <%= render_slot(@bottom_links) %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
