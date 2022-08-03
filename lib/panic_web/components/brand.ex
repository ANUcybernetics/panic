defmodule PanicWeb.Components.Brand do
  use Phoenix.Component

  # SETUP_TODO
  # This module relies on the following images. Replace these images with your logos
  # /priv/static/images/logo_dark.svg
  # /priv/static/images/logo_light.svg
  # /priv/static/images/logo_icon_dark.svg
  # /priv/static/images/logo_icon_light.svg
  # /priv/static/images/favicon.png

  @doc "Displays your full logo. "
  def logo(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "h-10" end)
      |> assign_new(:variant, fn -> nil end)

    ~H"""
    <%= if @variant do %>
      <img class={@class} src={"/images/logo_#{@variant}.svg"} />
    <% else %>
      <img class={@class <> " block dark:hidden"} src="/images/logo_dark.svg" />
      <img class={@class <> " hidden dark:block"} src="/images/logo_light.svg" />
    <% end %>
    """
  end

  @doc "Displays just the icon part of your logo"
  def logo_icon(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "h-9 w-9" end)
      |> assign_new(:variant, fn -> nil end)

    ~H"""
    <%= if @variant do %>
      <img class={@class} src={"/images/logo_icon_#{@variant}.svg"} />
    <% else %>
      <img class={@class <> " block dark:hidden"} src="/images/logo_icon_dark.svg" />
      <img class={@class <> " hidden dark:block"} src="/images/logo_icon_light.svg" />
    <% end %>
    """
  end

  def logo_for_emails(assigns) do
    ~H"""
    <img height="60" src={Panic.config(:logo_url_for_emails)} />
    """
  end
end
