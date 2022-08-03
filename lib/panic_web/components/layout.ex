defmodule PanicWeb.Components.Layout do
  use Phoenix.Component

  import PanicWeb.Components.Brand

  import PetalFramework.Components.{
    StackedLayout,
    SidebarLayout,
    PublicLayout,
    ColorSchemeSwitch,
    LanguageSelect
  }

  import PanicWeb.Helpers

  @doc """
  A kind of proxy layout allowing you to pass in a user. Layout components should have little knowledge about your application so this is a way you can pass in a user and it will build a lot of the attributes for you based off the user.

  Ideally you should modify this file a lot and not touch the actual layout components like "sidebar_layout" and "stacked_layout".
  If you're creating a new layout then duplicate "sidebar_layout" or "stacked_layout" and give it a new name. Then modify this file to allow your new layout. This way live views can keep using this component and simply switch the "type" attribute to your new layout.

  prop :type, :atom, options: ["stacked", "sidebar"]
  prop current_user, :map
  extra_props are passed on to the layout
  slot default
  """
  def layout(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> "sidebar" end)
      |> assign_new(:public_menu_items, fn -> public_menu_items(assigns[:current_user]) end)
      |> assign_new(:main_menu_items, fn -> main_menu_items(assigns[:current_user]) end)
      |> assign_new(:user_menu_items, fn -> user_menu_items(assigns[:current_user]) end)
      |> assign_new(:current_user_name, fn -> user_name(assigns[:current_user]) end)
      |> assign_new(:avatar_src, fn -> user_avatar_url(assigns[:current_user]) end)
      |> assign_new(:home_path, fn -> home_path(assigns[:current_user]) end)

    ~H"""
    <%= case @type do %>
      <% "sidebar" -> %>
        <.sidebar_layout {assigns}>
          <:logo>
            <.logo
              variant="light"
              class="h-8 transition-transform duration-300 ease-out transform hover:scale-105"
            />
          </:logo>
          <:top_right>
            <.color_scheme_switch />
          </:top_right>
          <%= render_slot(@inner_block) %>
        </.sidebar_layout>
      <% "stacked" -> %>
        <.stacked_layout {assigns}>
          <:logo>
            <div class="flex items-center flex-shrink-0 h-full">
              <div class="hidden lg:block">
                <.logo class="h-8" />
              </div>
              <div class="block lg:hidden">
                <.logo_icon class="w-auto h-8" />
              </div>
            </div>
          </:logo>
          <:top_right>
            <.color_scheme_switch />
          </:top_right>
          <%= render_slot(@inner_block) %>
        </.stacked_layout>
      <% "public" -> %>
        <.public_layout
          {assigns}
          twitter_url={Panic.config(:twitter_url)}
          github_url={Panic.config(:github_url)}
          discord_url={Panic.config(:discord_url)}
        >
          <:logo>
            <.logo class="h-10" />
          </:logo>
          <:top_right>
            <.language_select
              current_locale={Gettext.get_locale(PanicWeb.Gettext)}
              language_options={Panic.config(:language_options)}
            />
            <.color_scheme_switch />
          </:top_right>
          <%= render_slot(@inner_block) %>
        </.public_layout>
    <% end %>
    """
  end
end
