defmodule PanicWeb.Components.LandingPage do
  @moduledoc """
  A set of components for use in a landing page.
  """
  use Phoenix.Component
  use PetalComponents

  attr :image_src, :string, required: true
  attr :logo_cloud_title, :string, default: nil
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  attr :cloud_logo, :list, default: []
  slot(:title)
  slot(:description)

  def hero(assigns) do
    ~H"""
    <section
      id="hero"
      class="bg-gradient-to-b from-white to-slate-100 dark:from-slate-900 dark:to-slate-800"
    >
      <.container max_width={@max_width} class="relative z-10 py-20">
        <div class="flex flex-wrap items-center -mx-3">
          <div class="w-full px-3 lg:w-1/2">
            <div class="py-12">
              <div class="max-w-lg mx-auto mb-8 text-center lg:max-w-md lg:mx-0 lg:text-left">
                <.h1 class="fade-in-animation">
                  <%= render_slot(@title) %>
                </.h1>

                <p class="mt-6 text-lg leading-relaxed text-slate-500 dark:text-slate-400 fade-in-animation">
                  <%= render_slot(@description) %>
                </p>
              </div>
              <div class="space-x-2 text-center lg:text-left fade-in-animation">
                <%= render_slot(@action_buttons) %>
              </div>
            </div>
          </div>
          <div class="w-full px-3 mb-12 lg:w-1/2 lg:mb-0">
            <div class="flex items-center justify-center lg:h-128">
              <img
                id="hero-image"
                class="fade-in-from-right-animation lg:max-w-lg max-h-[500px]"
                src={@image_src}
                alt=""
              />
            </div>
          </div>
        </div>

        <%= if length(@cloud_logo) > 0 do %>
          <div class="mt-40">
            <.logo_cloud title={@logo_cloud_title} cloud_logo={@cloud_logo} />
          </div>
        <% end %>
      </.container>
    </section>
    """
  end

  attr :title, :string
  attr :cloud_logo, :list, default: [], doc: "List of slots"

  def logo_cloud(assigns) do
    ~H"""
    <div id="logo-cloud" class="container px-4 mx-auto">
      <%= if @title do %>
        <h2 class="mb-10 text-2xl text-center text-slate-500 fade-in-animation dark:text-slate-300">
          <%= @title %>
        </h2>
      <% end %>

      <div class="flex flex-wrap justify-center">
        <%= for logo <- @cloud_logo do %>
          <div class="w-full p-4 md:w-1/3 lg:w-1/6">
            <div class="py-4 lg:py-8">
              <%= render_slot(logo) %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :features, :list,
    default: [],
    doc:
      "A list of features, which are maps with the keys :icon (a HeroiconV1), :title and :description"

  attr :grid_classes, :string,
    default: "md:grid-cols-3",
    doc: "Tailwind grid cols class to specify how many columns you want"

  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]

  def features(assigns) do
    ~H"""
    <section
      id="features"
      class="relative z-10 py-16 text-center transition duration-500 ease-in-out bg-white md:py-32 dark:bg-slate-900 dark:text-white"
    >
      <.container max_width={@max_width} class="relative z-10">
        <div class="mx-auto mb-16 md:mb-20 lg:w-7/12 stagger-fade-in-animation">
          <div class="mb-5 text-3xl font-bold md:mb-7 md:text-5xl fade-in-animation">
            <%= @title %>
          </div>
          <div class="text-lg font-light anim md:text-2xl fade-in-animation">
            <%= @description %>
          </div>
        </div>

        <div class={["grid stagger-fade-in-animation gap-y-8", @grid_classes]}>
          <%= for feature <- @features do %>
            <div class="px-8 mb-10 border-slate-200 md:px-16 fade-in-animation last:border-0">
              <div class="flex justify-center mb-4 md:mb-6">
                <span class="flex items-center justify-center w-12 h-12 rounded-md bg-primary-600">
                  <HeroiconsV1.Outline.render icon={feature.icon} class="w-6 h-6 text-white" />
                </span>
              </div>
              <div class="mb-2 text-lg font-medium md:text-2xl">
                <%= feature.title %>
              </div>
              <p class="font-light leading-normal md:text-lg">
                <%= feature.description %>
              </p>
            </div>
          <% end %>
        </div>
      </.container>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :image_src, :string, required: true
  attr :inverted, :boolean, default: false
  attr :background_color, :string, default: "primary"
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  slot(:inner_block)

  def solo_feature(assigns) do
    ~H"""
    <section
      id="benefits"
      class="overflow-hidden transition duration-500 ease-in-out bg-slate-50 md:pt-0 dark:bg-slate-800 dark:text-white"
      data-offset="false"
    >
      <.container max_width={@max_width}>
        <div class={
          "#{if @inverted, do: "flex-row-reverse", else: ""} flex flex-wrap items-center gap-20 py-32 md:flex-nowrap"
        }>
          <div class="md:w-1/2 stagger-fade-in-animation">
            <div class="mb-5 text-3xl font-bold md:mb-7 fade-in-animation md:text-5xl">
              <%= @title %>
            </div>

            <div class="space-y-4 text-lg font-light md:text-xl md:space-y-5">
              <p class="fade-in-animation">
                <%= @description %>
              </p>
            </div>
            <%= if render_slot(@inner_block) do %>
              <div class="fade-in-animation">
                <%= render_slot(@inner_block) %>
              </div>
            <% end %>
          </div>

          <div class="w-full md:w-1/2 md:mt-0">
            <div class={
              "#{if @background_color == "primary", do: "from-primary-200 to-primary-600 bg-primary-animation"} #{if @background_color == "secondary", do: "from-secondary-200 to-secondary-600 bg-secondary-animation"} relative flex items-center justify-center w-full p-16 bg-gradient-to-r rounded-3xl"
            }>
              <img
                class="z-10 w-full fade-in-animation solo-animation max-h-[500px]"
                src={@image_src}
                alt="Screenshot"
              />
            </div>
          </div>
        </div>
      </.container>
    </section>
    """
  end

  attr :title, :string, default: "Testimonials"
  attr :testimonials, :list, doc: "A list of maps with the keys: content, image_src, name, title"
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]

  def testimonials(assigns) do
    ~H"""
    <section
      id="testimonials"
      class="relative z-10 transition duration-500 ease-in-out bg-white py-36 dark:bg-slate-900"
    >
      <div class="overflow-hidden content-wrapper">
        <.container max_width={@max_width} class="relative z-10">
          <div class="mb-5 text-center md:mb-12 section-header stagger-fade-in-animation">
            <div class="mb-3 text-3xl font-bold leading-none dark:text-white md:mb-5 fade-in-animation md:text-5xl">
              <%= @title %>
            </div>
          </div>

          <div class="solo-animation fade-in-animation flickity">
            <%= for testimonial <- @testimonials do %>
              <.testimonial_panel {testimonial} />
            <% end %>
          </div>
        </.container>
      </div>
    </section>

    <script phx-update="ignore" id="testimonials-js" type="module">
      // Flickity allows for a touch-enabled slideshow - used for testimonials
      import flickity from 'https://cdn.skypack.dev/flickity@2';

      let el = document.querySelector(".flickity");

      if(el){
        new flickity(el, {
          cellAlign: "left",
          prevNextButtons: false,
          adaptiveHeight: false,
          cellSelector: ".carousel-cell",
        });
      }
    </script>

    <link
      rel="stylesheet"
      href="https://cdnjs.cloudflare.com/ajax/libs/flickity/2.3.0/flickity.min.css"
      integrity="sha512-B0mpFwHOmRf8OK4U2MBOhv9W1nbPw/i3W1nBERvMZaTWd3+j+blGbOyv3w1vJgcy3cYhzwgw1ny+TzWICN35Xg=="
      crossorigin="anonymous"
      referrerpolicy="no-referrer"
    />
    <style>
      /* Modify the testimonial slider to go off the page */
      #testimonials .flickity-viewport {
        overflow: unset;
      }

      #testimonials .flickity-page-dots {
        position: relative;
        bottom: unset;
        margin-top: 40px;
        text-align: center;
      }

      #testimonials .flickity-page-dots .dot {
        background: #3b82f6;
        transition: 0.3s all ease;
        opacity: 0.35;
        margin: 0;
        margin-right: 10px;
      }

      #testimonials .flickity-page-dots .dot.is-selected {
        opacity: 1;
      }

      .dark #testimonials .flickity-page-dots .dot {
        background: white;
      }
    </style>
    """
  end

  attr :content, :string, required: true
  attr :image_src, :string, required: true
  attr :name, :string, required: true
  attr :title, :string, required: true

  def testimonial_panel(assigns) do
    ~H"""
    <div class="w-full p-6 mr-10 overflow-hidden transition duration-500 ease-in-out rounded-lg shadow-lg text-slate-700 md:p-8 md:w-8/12 lg:w-5/12 bg-primary-50 dark:bg-slate-700 dark:text-white carousel-cell last:mr-0">
      <blockquote class="mt-6 md:flex-grow md:flex md:flex-col">
        <div class="relative text-lg font-medium md:flex-grow">
          <svg
            class="absolute top-[-20px] left-0 w-8 h-8 transform -translate-x-3 -translate-y-2 text-primary-500"
            fill="currentColor"
            viewBox="0 0 32 32"
            aria-hidden="true"
          >
            <path d="M9.352 4C4.456 7.456 1 13.12 1 19.36c0 5.088 3.072 8.064 6.624 8.064 3.36 0 5.856-2.688 5.856-5.856 0-3.168-2.208-5.472-5.088-5.472-.576 0-1.344.096-1.536.192.48-3.264 3.552-7.104 6.624-9.024L9.352 4zm16.512 0c-4.8 3.456-8.256 9.12-8.256 15.36 0 5.088 3.072 8.064 6.624 8.064 3.264 0 5.856-2.688 5.856-5.856 0-3.168-2.304-5.472-5.184-5.472-.576 0-1.248.096-1.44.192.48-3.264 3.456-7.104 6.528-9.024L25.864 4z">
            </path>
          </svg>
          <p class="relative">
            <%= @content %>
          </p>
        </div>
        <footer class="mt-8">
          <div class="flex items-start">
            <div class="inline-flex flex-shrink-0 border-2 border-white rounded-full">
              <img class="w-12 h-12 rounded-full" src={@image_src} alt="" />
            </div>
            <div class="ml-4">
              <div class="text-base font-medium"><%= @name %></div>
              <div class="text-base font-semibold"><%= @title %></div>
            </div>
          </div>
        </footer>
      </blockquote>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]

  attr :plans, :list,
    doc:
      "List of maps with keys: :most_popular (bool), :name, :currency, :price, :unit, :description, :features (list of strings)"

  def pricing(assigns) do
    ~H"""
    <section
      id="pricing"
      class="py-24 transition duration-500 ease-in-out text-slate-700 md:py-32 dark:bg-slate-800 bg-slate-50 dark:text-white stagger-fade-in-animation"
    >
      <.container max_width={@max_width}>
        <div class="mx-auto mb-16 text-center md:mb-20 lg:w-7/12 ">
          <div class="mb-5 text-3xl font-bold md:mb-7 md:text-5xl fade-in-animation">
            <%= @title %>
          </div>
          <div class="text-lg font-light anim md:text-2xl fade-in-animation">
            <%= @description %>
          </div>
        </div>

        <div class="grid items-start max-w-sm gap-8 mx-auto lg:grid-cols-3 lg:gap-6 lg:max-w-none">
          <%= for plan <- @plans do %>
            <.pricing_table {plan} />
          <% end %>
        </div>
      </.container>
    </section>
    """
  end

  attr :most_popular, :boolean, default: false
  attr :currency, :string, default: "$"
  attr :unit, :string, default: "/m"
  attr :name, :string, required: true
  attr :price, :string, required: true
  attr :description, :string, required: true
  attr :features, :list, default: []

  def pricing_table(assigns) do
    ~H"""
    <div class="relative flex flex-col h-full p-6 transition duration-500 ease-in-out rounded-lg bg-slate-200 dark:bg-slate-900 fade-in-animation">
      <%= if @most_popular do %>
        <div class="absolute top-0 right-0 mr-6 -mt-4">
          <div class="inline-flex px-3 py-1 mt-px text-sm font-semibold text-green-600 bg-green-200 rounded-full">
            Most Popular
          </div>
        </div>
      <% end %>

      <div class="pb-4 mb-4 transition duration-500 ease-in-out border-b border-slate-300 dark:border-slate-700">
        <div class="mb-1 text-2xl font-bold leading-snug tracking-tight dark:text-primary-500 text-primary-600">
          <%= @name %>
        </div>

        <div class="inline-flex items-baseline mb-2">
          <span class="text-2xl font-medium text-slate-600 dark:text-slate-400">
            <%= @currency %>
          </span>
          <span class="text-3xl font-extrabold leading-tight transition duration-500 ease-in-out text-slate-900 dark:text-white">
            <%= @price %>
          </span>
          <span class="font-medium text-slate-600 dark:text-slate-400"><%= @unit %></span>
        </div>

        <div class="text-slate-600 dark:text-slate-400">
          <%= @description %>
        </div>
      </div>

      <div class="mb-3 font-medium text-slate-700 dark:text-slate-200">
        Features include:
      </div>

      <ul class="-mb-3 text-slate-600 dark:text-slate-400 grow">
        <%= for feature <- @features do %>
          <li class="flex items-center mb-3">
            <HeroiconsV1.Solid.check class="w-3 h-3 mr-3 text-green-500 fill-current shrink-0" />
            <span><%= feature %></span>
          </li>
        <% end %>
      </ul>

      <div class="p-3 mt-6 ">
        <.button link_type="a" to={@sign_up_path} class="w-full" label="Start free trial" />
      </div>
    </div>
    """
  end

  def load_js_animations(assigns) do
    ~H"""
    <script type="module">
      // Use GSAP for animations
      // https://greensock.com/gsap/
      import gsap from 'https://cdn.skypack.dev/gsap@3.10.4';

      // Put it on the window for when you want to try out animations in the console
      window.gsap = gsap;

      // A plugin for GSAP that detects when an element enters the viewport - this helps with timing the animation
      import ScrollTrigger from "https://cdn.skypack.dev/gsap@3.10.4/ScrollTrigger";
      gsap.registerPlugin(ScrollTrigger);

      animateHero();
      setupPageAnimations();

      // This is needed to ensure the animations timings are correct as you scroll
      setTimeout(() => {
        ScrollTrigger.refresh(true);
      }, 1000);

      function animateHero() {

        // A timeline just means you can chain animations together - one after another
        // https://greensock.com/docs/v3/GSAP/gsap.timeline()
        const heroTimeline = gsap.timeline({});

        heroTimeline
          .to("#hero .fade-in-animation", {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            ease: "power2.out",
            duration: 1,
          })
          .to("#hero-image", {
            opacity: 1,
            x: 0,
            duration: 0.4
          }, ">-1.3")
          .to("#logo-cloud .fade-in-animation", {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            ease: "power2.out",
          })
      }

      function setupPageAnimations() {

        // This allows us to give any individual HTML element the class "solo-animation"
        // and that element will fade in when scrolled into view
        gsap.utils.toArray(".solo-animation").forEach((item) => {
          gsap.to(item, {
            y: 0,
            opacity: 1,
            duration: 0.5,
            ease: "power2.out",
            scrollTrigger: {
              trigger: item,
            },
          });
        });

        // Add the class "stagger-fade-in-animation" to a parent element, then all elements within it
        // with the class "fade-in-animation" will fade in on scroll in a staggered formation to look
        // more natural than them all fading in at once
        gsap.utils.toArray(".stagger-fade-in-animation").forEach((stagger) => {
          const children = stagger.querySelectorAll(".fade-in-animation");
          gsap.to(children, {
            opacity: 1,
            y: 0,
            ease: "power2.out",
            stagger: 0.15,
            duration: 0.5,
            scrollTrigger: {
              trigger: stagger,
              start: "top 75%",
            },
          });
        });
      }
    </script>
    """
  end
end
