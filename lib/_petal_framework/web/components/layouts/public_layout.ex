defmodule PetalFramework.Components.PublicLayout do
  @moduledoc """
  This layout is for public pages like landing / about / pricing.
  """
  use Phoenix.Component
  use PetalComponents
  import PetalFramework.Components.UserDropdownMenu
  import PanicWeb.Helpers

  def public_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:public_menu_items, fn -> [] end)
      |> assign_new(:user_menu_items, fn -> [] end)
      |> assign_new(:twitter_url, fn -> nil end)
      |> assign_new(:github_url, fn -> nil end)
      |> assign_new(:discord_url, fn -> nil end)
      |> assign_new(:top_right, fn -> nil end)
      |> assign_new(:max_width, fn -> "lg" end)
      |> assign_new(:header_class, fn -> "" end)

    ~H"""
    <.public_layout_header
      current_user={@current_user}
      current_page={@current_page}
      public_menu_items={@public_menu_items}
      user_menu_items={@user_menu_items}
      avatar_src={@avatar_src}
      logo={@logo}
      top_right={@top_right}
      max_width={@max_width}
      header_class={@header_class}
    />

    <div class="pt-[64px] md:pt-0">
      <%= render_slot(@inner_block) %>
    </div>

    <.public_layout_footer
      public_menu_items={@public_menu_items}
      twitter_url={@twitter_url}
      github_url={@github_url}
      discord_url={@discord_url}
      logo={@logo}
      max_width={@max_width}
    />
    """
  end

  def public_layout_header(assigns) do
    assigns =
      assigns
      |> assign_new(:user_menu_items, fn -> [] end)
      |> assign_new(:public_menu_items, fn -> [] end)
      |> assign_new(:avatar_src, fn -> nil end)
      |> assign_new(:top_right, fn -> nil end)
      |> assign_new(:max_width, fn -> "lg" end)
      |> assign_new(:header_class, fn -> "" end)

    ~H"""
    <script>
      // When you scroll down, you will notice the navbar becomes translucent.
      function makeHeaderTranslucentOnScroll() {
        const header = document.querySelector("header");
        if (header) {
          const distanceFromTop = window.scrollY;
          distanceFromTop > 0
            ? header.classList.add("is-active")
            : header.classList.remove("is-active");
        }
      }
    </script>

    <style>
      /* Hover effects for the top menu */
      header .menu-item {
        position: relative;
      }

      header .menu-item:before {
        content: '';
        position: absolute;
        right: 0;
        width: 0;
        bottom: 0;
        height: 2px;
        background: #4b5563;
        transition: 0.3s all ease;
      }

      .dark header .menu-item:before {
        background: #ccc;
      }

      header .menu-item:hover:before {
        left: 0;
        width: 100%;
      }

      header .menu-item.is-active:before {
        left: 0;
        width: 100%;
      }

      /* Translucent effects for the the navbar when you scroll down the page */
      header.is-active {
        background: rgba(255, 255, 255, .55);
        @apply shadow;
      }

      .dark header.is-active {
        background: rgba(0,0,0,.45);
        @apply shadow;
      }

      header.is-active.semi-translucent {
        backdrop-filter: saturate(180%) blur(10px);
        -webkit-backdrop-filter: saturate(180%) blur(10px);
        -moz-backdrop-filter: saturate(180%) blur(10px);
      }
    </style>

    <header
      x-data="{mobile: false}"
      x-init="window.addEventListener('scroll', makeHeaderTranslucentOnScroll)"
      class={
        [
          "fixed top-0 left-0 z-30 w-full transition duration-500 ease-in-out md:sticky semi-translucent",
          @header_class
        ]
      }
    >
      <.container max_width={@max_width}>
        <div class="flex flex-wrap items-center h-16 md:h-18">
          <div class="lg:w-3/12">
            <div class="flex items-center">
              <.link class="inline-block ml-1 text-2xl font-bold leading-none" to="/">
                <%= render_slot(@logo) %>
              </.link>

              <.link class="hidden ml-3 lg:block" to="/" />
            </div>
          </div>

          <div class="hidden lg:w-6/12 md:block">
            <ul class="justify-center md:flex">
              <.list_menu_items
                li_class="ml-8 lg:mx-4 xl:mx-6"
                a_class="block font-medium leading-7 capitalize dark:text-slate-100 menu-item"
                menu_items={@public_menu_items}
              />
            </ul>
          </div>

          <div class="flex items-center justify-end ml-auto lg:w-3/12">
            <div class="flex items-center gap-3 mr-4">
              <%= if @top_right do %>
                <%= render_slot(@top_right) %>
              <% end %>
            </div>

            <div class="hidden md:block">
              <.user_menu_dropdown
                user_menu_items={@user_menu_items}
                avatar_src={@avatar_src}
                current_user_name={if @current_user, do: user_name(@current_user), else: nil}
              />
            </div>

            <div
              @click="mobile = !mobile"
              class="relative inline-block w-5 h-5 cursor-pointer md:hidden"
            >
              <svg
                :class="{ 'opacity-1' : !mobile, 'opacity-0' : mobile }"
                width="24"
                height="24"
                fill="none"
                class="absolute -mt-3 -ml-3 transform top-1/2 left-1/2"
              >
                <path
                  d="M4 8h16M4 16h16"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>

              <svg
                :class="{ 'opacity-0' : !mobile }"
                width="24"
                height="24"
                fill="none"
                class="absolute -mt-3 -ml-3 transform opacity-0 top-1/2 left-1/2 scale-80"
              >
                <path
                  d="M6 18L18 6M6 6l12 12"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
            </div>
          </div>
        </div>

        <div :class="{ 'block' : mobile, 'hidden' : !mobile }" class="md:hidden">
          <hr class="border-primary-900 border-opacity-10 dark:border-slate-700" />
          <ul class="py-6">
            <.list_menu_items
              li_class="mb-2 last:mb-0 dark:text-slate-400"
              a_class="inline-block font-medium capitalize menu-item"
              menu_items={@public_menu_items}
            />

            <%= if @current_user do %>
              <div class="pt-4 pb-3">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <%= if @current_user.name do %>
                      <.avatar name={@current_user.name} size="sm" random_color />
                    <% else %>
                      <.avatar size="sm" />
                    <% end %>
                  </div>
                  <div class="ml-3">
                    <div class="text-base font-medium text-slate-800 dark:text-slate-300">
                      <%= @current_user.name %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <.list_menu_items
              li_class="mb-2 last:mb-0"
              a_class="inline-block font-medium capitalize menu-item dark:text-slate-400"
              menu_items={@user_menu_items}
            />
          </ul>
        </div>
      </.container>
    </header>
    """
  end

  defp list_menu_items(assigns) do
    ~H"""
    <%= for menu_item <- @menu_items do %>
      <li class={@li_class}>
        <.link
          to={menu_item.path}
          class={@a_class}
          link_type="a"
          method={if menu_item[:method], do: menu_item[:method], else: nil}
        >
          <%= menu_item.label %>
        </.link>
      </li>
    <% end %>
    """
  end

  def public_layout_footer(assigns) do
    assigns =
      assigns
      |> assign_new(:public_menu_items, fn -> [] end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section>
      <div class="py-20">
        <.container max_width={@max_width}>
          <div class="flex flex-wrap items-center justify-between pb-12 border-b border-slate-200 dark:border-slate-800">
            <div class="w-full mb-12 md:w-1/5 md:mb-0">
              <a class="inline-block text-3xl font-bold leading-none" href="/">
                <%= render_slot(@logo) %>
              </a>
            </div>
            <div class="w-full md:w-auto">
              <ul class="flex flex-wrap items-center md:space-x-5">
                <.list_menu_items
                  li_class="w-full mb-2 md:w-auto md:mb-0"
                  a_class="text-slate-700 dark:text-slate-300 md:text-sm hover:text-slate-800 dark:hover:text-slate-400"
                  menu_items={@public_menu_items}
                />
              </ul>
            </div>
          </div>
          <div class="flex flex-wrap items-center justify-between mt-8">
            <div class="order-last text-sm text-slate-600 dark:text-slate-400">
              <div>© <%= Timex.now().year %> Everfree Pty Ltd. All rights reserved.</div>

              <div class="mt-2 divide-x divide-slate-500 dark:divide-slate-400">
                <.link
                  to="/privacy"
                  label="Privacy Policy"
                  class="pr-3 hover:text-slate-900 dark:hover:text-slate-300"
                />
                <.link
                  to="/license"
                  label="License"
                  class="px-3 hover:text-slate-900 dark:hover:text-slate-300"
                />
              </div>
            </div>
            <div class="order-first mb-4 md:mb-0 md:order-last">
              <%= if @twitter_url do %>
                <a target="_blank" class={social_a_class()} href={@twitter_url}>
                  <svg
                    class={social_svg_class()}
                    xmlns="http://www.w3.org/2000/svg"
                    data-name="Layer 1"
                    viewBox="0 0 24 24"
                  >
                    <path d="M22,5.8a8.49,8.49,0,0,1-2.36.64,4.13,4.13,0,0,0,1.81-2.27,8.21,8.21,0,0,1-2.61,1,4.1,4.1,0,0,0-7,3.74A11.64,11.64,0,0,1,3.39,4.62a4.16,4.16,0,0,0-.55,2.07A4.09,4.09,0,0,0,4.66,10.1,4.05,4.05,0,0,1,2.8,9.59v.05a4.1,4.1,0,0,0,3.3,4A3.93,3.93,0,0,1,5,13.81a4.9,4.9,0,0,1-.77-.07,4.11,4.11,0,0,0,3.83,2.84A8.22,8.22,0,0,1,3,18.34a7.93,7.93,0,0,1-1-.06,11.57,11.57,0,0,0,6.29,1.85A11.59,11.59,0,0,0,20,8.45c0-.17,0-.35,0-.53A8.43,8.43,0,0,0,22,5.8Z" />
                  </svg>
                </a>
              <% end %>

              <%= if @github_url do %>
                <a target="_blank" class={social_a_class()} href={@github_url}>
                  <svg
                    class={social_svg_class()}
                    xmlns="http://www.w3.org/2000/svg"
                    data-name="Layer 1"
                    viewBox="0 0 24 24"
                  >
                    <path d="M12,2.2467A10.00042,10.00042,0,0,0,8.83752,21.73419c.5.08752.6875-.21247.6875-.475,0-.23749-.01251-1.025-.01251-1.86249C7,19.85919,6.35,18.78423,6.15,18.22173A3.636,3.636,0,0,0,5.125,16.8092c-.35-.1875-.85-.65-.01251-.66248A2.00117,2.00117,0,0,1,6.65,17.17169a2.13742,2.13742,0,0,0,2.91248.825A2.10376,2.10376,0,0,1,10.2,16.65923c-2.225-.25-4.55-1.11254-4.55-4.9375a3.89187,3.89187,0,0,1,1.025-2.6875,3.59373,3.59373,0,0,1,.1-2.65s.83747-.26251,2.75,1.025a9.42747,9.42747,0,0,1,5,0c1.91248-1.3,2.75-1.025,2.75-1.025a3.59323,3.59323,0,0,1,.1,2.65,3.869,3.869,0,0,1,1.025,2.6875c0,3.83747-2.33752,4.6875-4.5625,4.9375a2.36814,2.36814,0,0,1,.675,1.85c0,1.33752-.01251,2.41248-.01251,2.75,0,.26251.1875.575.6875.475A10.0053,10.0053,0,0,0,12,2.2467Z" />
                  </svg>
                </a>
              <% end %>

              <%= if @discord_url do %>
                <a target="_blank" class={social_a_class()} href={@discord_url}>
                  <svg
                    class={social_svg_class()}
                    xmlns="http://www.w3.org/2000/svg"
                    data-name="Layer 1"
                    viewBox="0 0 16 16"
                  >
                    <path d="M13.545 2.907a13.227 13.227 0 0 0-3.257-1.011.05.05 0 0 0-.052.025c-.141.25-.297.577-.406.833a12.19 12.19 0 0 0-3.658 0 8.258 8.258 0 0 0-.412-.833.051.051 0 0 0-.052-.025c-1.125.194-2.22.534-3.257 1.011a.041.041 0 0 0-.021.018C.356 6.024-.213 9.047.066 12.032c.001.014.01.028.021.037a13.276 13.276 0 0 0 3.995 2.02.05.05 0 0 0 .056-.019c.308-.42.582-.863.818-1.329a.05.05 0 0 0-.01-.059.051.051 0 0 0-.018-.011 8.875 8.875 0 0 1-1.248-.595.05.05 0 0 1-.02-.066.051.051 0 0 1 .015-.019c.084-.063.168-.129.248-.195a.05.05 0 0 1 .051-.007c2.619 1.196 5.454 1.196 8.041 0a.052.052 0 0 1 .053.007c.08.066.164.132.248.195a.051.051 0 0 1-.004.085 8.254 8.254 0 0 1-1.249.594.05.05 0 0 0-.03.03.052.052 0 0 0 .003.041c.24.465.515.909.817 1.329a.05.05 0 0 0 .056.019 13.235 13.235 0 0 0 4.001-2.02.049.049 0 0 0 .021-.037c.334-3.451-.559-6.449-2.366-9.106a.034.034 0 0 0-.02-.019Zm-8.198 7.307c-.789 0-1.438-.724-1.438-1.612 0-.889.637-1.613 1.438-1.613.807 0 1.45.73 1.438 1.613 0 .888-.637 1.612-1.438 1.612Zm5.316 0c-.788 0-1.438-.724-1.438-1.612 0-.889.637-1.613 1.438-1.613.807 0 1.451.73 1.438 1.613 0 .888-.631 1.612-1.438 1.612Z" />
                  </svg>
                </a>
              <% end %>
            </div>
          </div>
        </.container>
      </div>
    </section>
    """
  end

  defp social_a_class(),
    do:
      "inline-block p-2 rounded dark:bg-slate-800 bg-slate-500 hover:bg-slate-700 dark:hover:bg-slate-600 group"

  defp social_svg_class(), do: "w-5 h-5 fill-white dark:fill-slate-400 group-hover:fill-white"
end
