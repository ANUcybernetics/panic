defmodule PanicWeb.AboutLive do
  @moduledoc false
  use PanicWeb, :live_view

  def mount(_params, _session, socket) do
    html_content = MDEx.to_html!(read_markdown_file!())

    {:ok,
     socket
     |> assign(page_title: "About PANIC!")
     |> assign(content: html_content)}
  end

  def render(assigns) do
    ~H"""
    <div class="prose prose-invert text-purple-300">
      <%= raw(@content) %>
    </div>
    """
  end

  defp read_markdown_file! do
    :panic
    |> Application.app_dir("priv/static/md/about.md")
    |> File.read!()
  end
end
