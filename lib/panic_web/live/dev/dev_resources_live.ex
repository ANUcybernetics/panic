defmodule PanicWeb.DevResourcesLive do
  use PanicWeb, :live_view
  alias PanicWeb.DevLayoutComponent

  @impl true
  def render(assigns) do
    ~H"""
    <DevLayoutComponent.dev_layout current_page={:resources} current_user={@current_user}>
      <.container class="py-16">
        <.h2>Resources 🧰</.h2>
        <.h5 class="mt-5">
          Thanks for joining the Petal community! Here are a few handy resources to help you get off the ground as quickly as possible 🚀
        </.h5>
        <div class="grid gap-5 mt-12 lg:grid-cols-2 xl:grid-cols-4">
          <.card>
            <.card_media class={image_class()} src="/images/dashboard/guide.svg" />
            <.card_content category="Documentation" heading="Guide" class="dark:text-gray-400">
              A comprehensive guide to help you navigate your way around the boilerplate and introduce you to some of the included functionality.
            </.card_content>
            <.card_footer>
              <.button link_type="a" to="https://docs.petal.build" color="primary" target="_blank">
                <HeroiconsV1.Outline.external_link class="w-4 h-4 mr-2" /> Guide
              </.button>
            </.card_footer>
          </.card>

          <.card>
            <.card_media class={image_class()} src="/images/dashboard/admin.svg" />
            <.card_content
              category="Learning"
              heading="Creating a web app from start to finish"
              class="dark:text-gray-400"
            >
              Follow a step by step guide to creating a reminders web application using the Petal Pro boilerplate. We will cover everything from setup to deploying to production.
            </.card_content>
            <.card_footer>
              <.button
                link_type="a"
                target="_blank"
                to="https://docs.petal.build/petal-pro-documentation/guides/creating-a-web-app-from-start-to-finish"
                color="primary"
              >
                <HeroiconsV1.Outline.external_link class="w-4 h-4 mr-2" /> Start learning
              </.button>
            </.card_footer>
          </.card>

          <.card>
            <.card_media class={image_class()} src="/images/dashboard/emails.svg" />
            <.card_content
              category="Documentation"
              heading="Petal Components Docs"
              class="dark:text-gray-400"
            >
              Our library of components will get you up and running with a beautiful web app.
            </.card_content>
            <.card_footer>
              <.button
                link_type="a"
                target="_blank"
                to="https://petal.build/components"
                color="primary"
              >
                <HeroiconsV1.Outline.external_link class="w-4 h-4 mr-2" /> Petal Components
              </.button>
            </.card_footer>
          </.card>

          <.card>
            <.card_media class={image_class()} src="/images/dashboard/page_builder.svg" />
            <.card_content
              category="Developer tools"
              heading="Page builder"
              class="dark:text-gray-400"
            >
              The page builder allows you to quickly scaffold pages at a desired route. Simply navigate to an unclaimed route and you will see the builder.
            </.card_content>
            <.card_footer>
              <.button link_type="a" to="/my-new-page" color="primary">
                <HeroiconsV1.Outline.document_add class="w-4 h-4 mr-2" /> Create a page
              </.button>
            </.card_footer>
          </.card>
        </div>
      </.container>
    </DevLayoutComponent.dev_layout>
    """
  end

  defp image_class(), do: "p-8 !object-contain dark:bg-gray-400/10 bg-gray-50 h-[250px]"
end
