defmodule PetalFramework.Components.Markdown do
  @moduledoc """
  Uses Earmark. Supports Github Flavored Markdown. Syntax highlighting is not supported yet.
  """

  use Phoenix.Component

  @doc """
  Renders markdown beautifully using Tailwind Typography classes.

      <.pretty_markdown content="# My markdown">
  """
  def pretty_markdown(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:extra_assigns, fn ->
        assigns_to_attributes(assigns, ~w(
          class
        )a)
      end)

    ~H"""
    <div
      {@extra_assigns}
      class={
        [
          "prose lg:prose-lg dark:prose-invert prose-img:rounded-xl prose-img:mx-auto prose-a:text-primary-600 prose-a:dark:text-primary-300",
          @class
        ]
      }
    >
      <.markdown content={@content} />
    </div>
    """
  end

  @doc """
  Renders markdown to html.
  """
  def markdown(assigns) do
    ~H"""
    <%= PetalFramework.MarkdownRenderer.to_html(@content) |> Phoenix.HTML.raw() %>
    """
  end
end
