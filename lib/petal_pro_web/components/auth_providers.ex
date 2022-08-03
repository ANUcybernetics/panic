defmodule PetalProWeb.Components.AuthProviders do
  use Phoenix.Component
  import PetalComponents.Link
  alias PetalComponents.Heroicons
  import PetalFramework.Components.SocialButton
  import PetalProWeb.Helpers
  import PetalProWeb.Gettext
  alias PetalProWeb.Router.Helpers, as: Routes

  # Shows the login buttons for all available providers. Can add a break "Or login with"
  # prop :or_location, :string, options: ["top", "bottom"]
  # prop :conn_or_socket, :map
  def auth_providers(assigns) do
    assigns =
      assigns
      |> assign_new(:or_location, fn -> nil end)
      |> assign_new(:or_text, fn -> "Or" end)

    ~H"""
    <%= if auth_provider_loaded?("google") || auth_provider_loaded?("github") || auth_provider_loaded?("passwordless") do %>
      <%= if @or_location == "top" do %>
        <.or_break or_text={@or_text} />
      <% end %>

      <div class="flex flex-col gap-2">
        <%= if auth_provider_loaded?("passwordless") do %>
          <.link
            link_type="a"
            to={Routes.passwordless_auth_path(@conn_or_socket, :sign_in)}
            class="inline-flex items-center justify-center w-full px-4 py-2 text-sm font-medium leading-5 text-gray-700 bg-white border border-gray-300 rounded-md hover:text-gray-900 hover:border-gray-400 hover:bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-gray-100 focus:text-gray-900 active:border-gray-400 active:bg-gray-200 active:text-black dark:text-gray-300 dark:focus:text-gray-100 dark:active:text-gray-100 dark:hover:text-gray-200 dark:bg-transparent dark:hover:bg-gray-800 dark:hover:border-gray-400 dark:border-gray-500 dark:focus:border-gray-300 dark:active:border-gray-300"
          >
            <Heroicons.Outline.mail class="w-5 h-5" />
            <span class="ml-2"><%= gettext("Continue with passwordless") %></span>
          </.link>
        <% end %>

        <%= if auth_provider_loaded?("google") do %>
          <.social_button
            link_type="a"
            to={Routes.user_ueberauth_path(@conn_or_socket, :request, "google")}
            variant="outline"
            logo="google"
            class="w-full"
          />
        <% end %>

        <%= if auth_provider_loaded?("github") do %>
          <.social_button
            link_type="a"
            to={Routes.user_ueberauth_path(@conn_or_socket, :request, "github")}
            variant="outline"
            logo="github"
            class="w-full"
          />
        <% end %>
      </div>

      <%= if @or_location == "bottom" do %>
        <.or_break or_text={@or_text} />
      <% end %>
    <% end %>
    """
  end

  # Shows a line with some text in the middle of the line. eg "Or login with"
  # prop or_text, :string
  def or_break(assigns) do
    ~H"""
    <div class="relative my-5">
      <div class="absolute inset-0 flex items-center">
        <div class="w-full border-t border-gray-300 dark:border-gray-600"></div>
      </div>
      <div class="relative flex justify-center text-sm">
        <span class="px-2 text-gray-500 bg-white dark:bg-gray-800">
          <%= @or_text %>
        </span>
      </div>
    </div>
    """
  end
end
