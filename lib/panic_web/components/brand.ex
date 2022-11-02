defmodule PanicWeb.Components.Brand do
  use Phoenix.Component
  alias PanicWeb.Router.Helpers, as: Routes
  alias PanicWeb.Endpoint

  @doc "Displays your full logo. "

  attr :class, :string, default: "h-10"
  attr :variant, :string, default: "both", values: ["dark", "light", "both"]

  def logo(assigns) do
    ~H"""
    <%= if Enum.member?(["light", "dark"], @variant) do %>
      <img class={@class} src={Routes.static_path(Endpoint, "/images/logo_#{@variant}.svg")} />
    <% else %>
      <img
        class={@class <> " block dark:hidden"}
        src={Routes.static_path(Endpoint, "/images/logo_dark.svg")}
      />
      <img
        class={@class <> " hidden dark:block"}
        src={Routes.static_path(Endpoint, "/images/logo_light.svg")}
      />
    <% end %>
    """
  end

  @doc "Displays just the icon part of your logo"

  attr :class, :string, default: "h-9 w-9"
  attr :variant, :string, default: "both", values: ["dark", "light", "both"]

  def logo_icon(assigns) do
    ~H"""
    <%= if Enum.member?(["light", "dark"], @variant) do %>
      <img class={@class} src={Routes.static_path(Endpoint, "/images/logo_icon_#{@variant}.svg")} />
    <% else %>
      <img
        class={@class <> " block dark:hidden"}
        src={Routes.static_path(Endpoint, "/images/logo_icon_dark.svg")}
      />
      <img
        class={@class <> " hidden dark:block"}
        src={Routes.static_path(Endpoint, "/images/logo_icon_light.svg")}
      />
    <% end %>
    """
  end

  def logo_for_emails(assigns) do
    ~H"""
    <img height="60" src={Panic.config(:logo_url_for_emails)} />
    """
  end
end
