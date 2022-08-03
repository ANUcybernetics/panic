defmodule PanicWeb.DevDashboardLive do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <PanicWeb.DevLayoutComponent.dev_layout current_page={:dev} current_user={@current_user}>
      <.container class="py-16">
        <.h2>Welcome, <%= user_name(@current_user) %> 👋</.h2>
        <.h5 class="mt-5">
          Thanks for joining the Petal community! Here are a few handy resources to help you get off the ground as quickly as possible 🚀
        </.h5>
        <div class="grid gap-5 mt-12 lg:grid-cols-2 xl:grid-cols-4">
          <.card>
            <.card_media class={image_class()} src="/images/dashboard/guide.svg" />
            <.card_content category="Developer tools" heading="Guide" class="dark:text-gray-400">
              A comprehensive guide to help you navigate your way around the boilerplate and introduce you to some of the included functionality.
            </.card_content>
            <.card_footer>
              <.button link_type="a" to="https://docs.petal.build" color="primary" target="_blank">
                <Heroicons.Outline.book_open class="w-4 h-4 mr-2" /> Guide
              </.button>
            </.card_footer>
          </.card>

          <.card>
            <.card_media class={image_class()} src="/images/dashboard/admin.svg" />
            <.card_content category="Admin tools" heading="Users and logs" class="dark:text-gray-400">
              View a list of users and perform actions such as suspend or delete. You can also view user logs, where you can track specific user actions and monitor how users use your application.
            </.card_content>
            <.card_footer>
              <.button link_type="a" to="/admin/users" color="primary">
                <Heroicons.Outline.lock_closed class="w-4 h-4 mr-2" /> Admin
              </.button>
            </.card_footer>
          </.card>

          <.card>
            <.card_media class={image_class()} src="/images/dashboard/emails.svg" />
            <.card_content
              category="Developer tools"
              heading="HTML email previewer"
              class="dark:text-gray-400"
            >
              Create and edit your transactional emails with our custom built HTML email template previewer. You can also check sent emails in the sent emails tab.
            </.card_content>
            <.card_footer>
              <.button link_type="a" to="/dev/emails/preview/template" color="primary">
                <Heroicons.Outline.code class="w-4 h-4 mr-2" /> Email previewer
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
                <Heroicons.Outline.document_add class="w-4 h-4 mr-2" /> Create a page
              </.button>
            </.card_footer>
          </.card>
        </div>
      </.container>
    </PanicWeb.DevLayoutComponent.dev_layout>
    """
  end

  defp image_class(), do: "p-8 !object-contain dark:bg-gray-400/10 bg-gray-50 h-[250px]"
end
