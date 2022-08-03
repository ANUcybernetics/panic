defmodule PetalFramework.Components.LanguageSelect do
  use Phoenix.Component
  alias PetalComponents.Heroicons
  import PetalComponents.Dropdown

  # prop :current_path, :string
  # prop :current_locale, :string
  # prop :language_options, :list
  @doc """
  Usage:
  <.language_select
    current_locale={Gettext.get_locale(PanicWeb.Gettext)}
    language_options={Panic.config(:language_options)}
  />
  """
  def language_select(assigns) do
    assigns =
      assigns
      |> assign_new(:current_path, fn -> "/" end)

    ~H"""
    <.dropdown>
      <:trigger_element>
        <div class="inline-flex items-center justify-center w-full gap-1 align-middle focus:outline-none">
          <div class="text-2xl">
            <%= Enum.find(@language_options, &(&1.locale == @current_locale)).flag %>
          </div>
          <Heroicons.Solid.chevron_down class="w-4 h-4 text-gray-400 dark:text-gray-100" />
        </div>
      </:trigger_element>
      <%= for language <- @language_options do %>
        <.dropdown_menu_item link_type="a" to={@current_path <> "?locale=#{language.locale}"}>
          <div class="mr-2 text-2xl leading-none"><%= language.flag %></div>
          <div><%= language.label %></div>
        </.dropdown_menu_item>
      <% end %>
    </.dropdown>
    """
  end
end
