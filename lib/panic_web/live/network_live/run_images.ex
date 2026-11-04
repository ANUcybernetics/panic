defmodule PanicWeb.NetworkLive.RunImages do
  @moduledoc """
  A run's images, one to a screen, for swiping back through on a phone. It's
  public, so the terminal's link to it outlives an anonymous terminal's token,
  and it follows the run as new images arrive.

  The page is for phones on cell data. It ships every image's tiny placeholder
  (`Panic.Engine.Archiver.placeholder/1`) but none of the images, except the
  newest; its hook loads the rest only around where the viewer settles, so a
  fling across the run costs placeholders rather than downloads.

  The scroller runs `row-reverse` with the newest image first in the DOM, so
  the page opens on the newest image before the hook (or the socket) is up.
  """
  use PanicWeb, :live_view

  alias Panic.Engine
  alias Panic.Engine.Invocation
  alias Phoenix.Socket.Broadcast

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.display flash={@flash}>
      <style>
        :root {
          font-size: 100%;
        }

        #run-images-slides {
          display: flex;
          flex-direction: row-reverse;
          overflow-x: auto;
          overscroll-behavior-x: contain;
          overflow-anchor: none;
          scroll-snap-type: x mandatory;
          scrollbar-width: none;
        }

        #run-images-slides > .slide {
          position: relative;
          flex: none;
          width: 100%;
          height: 100%;
          overflow: hidden;
          scroll-snap-align: center;
          content-visibility: auto;
        }

        /* the placeholder twice: as an ambient wash behind the image, and blurred
           where the image will be */
        #run-images-slides > .slide::before,
        #run-images-slides > .slide::after {
          content: "";
          position: absolute;
        }

        #run-images-slides > .slide::before {
          inset: -10%;
          background: var(--placeholder) center / cover;
          filter: blur(40px) brightness(0.5);
        }

        #run-images-slides > .slide::after {
          inset: 0;
          background: var(--placeholder) center / contain no-repeat;
          filter: blur(8px);
        }

        #run-images-slides > .slide img {
          position: absolute;
          inset: 0;
          z-index: 1;
          width: 100%;
          height: 100%;
          object-fit: contain;
          opacity: 0;
          transition: opacity 0.3s;
        }

        #run-images-slides > .slide img.loaded {
          opacity: 1;
        }

        @media (prefers-reduced-motion: reduce) {
          #run-images-slides > .slide img {
            transition: none;
          }
        }
      </style>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".RunImages">
        // The slides are in reverse: slide 0 (first in the DOM, rightmost) is the
        // newest. `back` is how many slides back from the newest the viewer is.
        export default {
          mounted() {
            this.scroller = this.el.querySelector("#run-images-slides");
            this.scrubber = this.el.querySelector("#run-images-scrubber");
            this.counter = this.el.querySelector("#run-images-counter");
            this.newButton = this.el.querySelector("#run-images-new");
            // slides whose image has been loaded, which a patch strips of its src
            this.wanted = new Set();
            this.count = this.slides().length;
            this.back = 0;
            this.currentId = this.slides()[0]?.id;

            this.scroller.addEventListener("load", (e) => e.target.classList.add("loaded"), true);
            this.scroller.addEventListener("scroll", () => this.onScroll(), { passive: true });
            this.scroller.addEventListener("scrollend", () => this.settle());
            // a drag along the scrubber passes over images it shouldn't load
            this.scrubber.addEventListener("input", () => {
              this.scrubbing = true;
              this.scrollTo(this.count - 1 - Number(this.scrubber.value), "instant");
            });
            this.scrubber.addEventListener("change", () => {
              this.scrubbing = false;
              this.settle();
            });
            this.newButton.addEventListener("click", () => this.scrollTo(0, this.motion()));

            this.observer = new MutationObserver((records) => this.onMutations(records));
            this.observer.observe(this.scroller, {
              childList: true,
              subtree: true,
              attributeFilter: ["src", "data-src"],
            });

            this.settle();
          },

          destroyed() {
            this.observer.disconnect();
          },

          slides() {
            return this.scroller.querySelectorAll(":scope > .slide");
          },

          motion() {
            return matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth";
          },

          position() {
            const width = this.scroller.clientWidth;
            return width ? Math.round(Math.abs(this.scroller.scrollLeft) / width) : 0;
          },

          scrollTo(back, behavior) {
            this.slides()[back]?.scrollIntoView({ inline: "center", block: "nearest", behavior });
          },

          onScroll() {
            if (!this.frame) {
              this.frame = requestAnimationFrame(() => {
                this.frame = null;
                this.track();
              });
            }
            // scrollend is Baseline only since Safari 26.2
            if (!("onscrollend" in window)) {
              clearTimeout(this.settleTimer);
              this.settleTimer = setTimeout(() => this.settle(), 150);
            }
          },

          // keeps the counter and scrubber on the slide in view
          track() {
            const slides = this.slides();
            this.count = slides.length;
            this.back = Math.min(this.position(), Math.max(this.count - 1, 0));
            this.currentId = slides[this.back]?.id;
            this.scrubber.max = Math.max(this.count - 1, 0);
            this.scrubber.value = this.count - 1 - this.back;
            this.scrubber.disabled = this.count < 2;
            this.counter.value = this.count ? `${this.count - this.back} / ${this.count}` : "";
            if (this.back === 0) this.newButton.hidden = true;
          },

          // loads the image in view, the next few older (where the viewer is
          // heading) and the next newer
          settle() {
            this.track();
            if (this.scrubbing) return;
            const slides = this.slides();
            [0, 1, 2, 3, -1].forEach((offset) => {
              const slide = slides[this.back + offset];
              if (slide) this.load(slide, offset === 0 ? "high" : "low");
            });
          },

          load(slide, priority = "low") {
            const img = slide.querySelector("img");
            this.wanted.add(slide.id);
            if (img.getAttribute("src") !== img.dataset.src) {
              img.fetchPriority = priority;
              img.src = img.dataset.src;
            } else if (img.complete && img.naturalWidth && !img.classList.contains("loaded")) {
              img.classList.add("loaded");
            }
          },

          onMutations(records) {
            const added = records.some((r) =>
              [...r.addedNodes].some((n) => n.classList?.contains("slide")),
            );

            // a patched slide loses the src the hook gave it
            this.wanted.forEach((id) => {
              const slide = document.getElementById(id);
              if (slide) this.load(slide);
              else this.wanted.delete(id);
            });

            if (added) {
              const wasNewest = this.back === 0;
              if (wasNewest) {
                // the new image arrives where the old newest was: slide over to it
                this.scrollTo(1, "instant");
                this.scrollTo(0, this.motion());
              } else {
                // stay on the image in view, which a new one has pushed along
                document
                  .getElementById(this.currentId)
                  ?.scrollIntoView({ inline: "center", block: "nearest", behavior: "instant" });
                this.newButton.hidden = false;
              }
              this.settle();
            }
          },
        };
      </script>
      <div id="run-images" phx-hook=".RunImages" class="fixed inset-0 bg-black text-white">
        <ol
          id="run-images-slides"
          phx-update="stream"
          class="size-full"
          tabindex="0"
          aria-label="This run's images, newest first"
        >
          <li
            :for={{id, invocation} <- @streams.images}
            id={id}
            class="slide"
            style={invocation.placeholder && "--placeholder: url(#{invocation.placeholder})"}
          >
            <%!-- the newest image needn't wait for the socket --%>
            <img
              data-src={invocation.output}
              src={invocation.id == @newest_id && invocation.output}
              fetchpriority={invocation.id == @newest_id && "high"}
              decoding="async"
              alt={alt(invocation)}
            />
            <p class="absolute inset-x-0 bottom-16 z-10 px-4 text-center text-xs text-white/70">
              {model_name(invocation)} · invocation {invocation.sequence_number}
            </p>
          </li>
          <li id="run-images-empty" class="hidden size-full place-items-center px-4 only:grid">
            No images yet. They'll appear here as the run makes them.
          </li>
        </ol>
        <header class="pointer-events-none absolute inset-x-0 top-0 z-10 bg-linear-to-b from-black/70 to-transparent p-4 pb-8">
          <p class="line-clamp-2 text-sm">
            <.link href={~p"/about"} class="pointer-events-auto font-bold">PANIC!</.link>
            <span class="text-white/70">{@genesis.input}</span>
          </p>
        </header>
        <%!-- the hook drives these, so patches leave them alone --%>
        <div
          id="run-images-controls"
          phx-update="ignore"
          class="absolute inset-x-0 bottom-0 z-10 flex items-center gap-3 bg-linear-to-t from-black/70 to-transparent p-4 pt-8"
        >
          <input
            id="run-images-scrubber"
            type="range"
            min="0"
            max="0"
            value="0"
            aria-label="Image in the run"
            class="range range-xs grow"
          />
          <output id="run-images-counter" class="whitespace-nowrap text-xs tabular-nums text-white/70"></output>
          <button
            id="run-images-new"
            type="button"
            hidden
            class="btn btn-sm btn-primary absolute right-4 bottom-16"
          >
            New image <.icon name="hero-arrow-right" class="size-4" />
          </button>
        </div>
      </div>
    </Layouts.display>
    """
  end

  @impl true
  def mount(%{"network_id" => network_id, "run_number" => run_number}, _session, socket) do
    case genesis(network_id, run_number) do
      {:ok, genesis} ->
        # subscribe before listing, so no image falls between the two
        if connected?(socket), do: PanicWeb.Endpoint.subscribe("invocation:#{genesis.network_id}")

        images = list_images(genesis)

        {:ok,
         socket
         |> assign(
           page_title: "Run #{genesis.run_number} images",
           genesis: genesis,
           newest_id: newest_id(images)
         )
         |> stream(:images, images)}

      :error ->
        {:ok, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(%Broadcast{event: event, payload: %{data: %Invocation{} = invocation}}, socket) do
    cond do
      not shown?(invocation, socket.assigns.genesis) ->
        {:noreply, socket}

      event == "invoke" ->
        {:noreply, stream_insert(socket, :images, invocation, at: 0)}

      # archiving moves an image to its permanent URL, with its placeholder
      event == "update_output" ->
        {:noreply, stream_insert(socket, :images, invocation, update_only: true)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # a run's number is its genesis invocation's id
  defp genesis(network_id, run_number) do
    with {network_id, ""} <- Integer.parse(network_id),
         {run_number, ""} <- Integer.parse(run_number),
         {:ok,
          %Invocation{network_id: ^network_id, run_number: ^run_number, sequence_number: 0} =
            genesis} <-
           Engine.get_invocation(run_number, authorize?: false) do
      {:ok, genesis}
    else
      _ -> :error
    end
  end

  defp list_images(genesis) do
    Engine.list_invocations!(
      query: [
        filter: [
          network_id: genesis.network_id,
          run_number: genesis.run_number,
          state: :completed,
          model: [in: image_model_ids()]
        ],
        sort: [sequence_number: :desc],
        select: [
          :id,
          :network_id,
          :run_number,
          :sequence_number,
          :model,
          :input,
          :output,
          :placeholder,
          :state
        ]
      ],
      page: false,
      authorize?: false
    )
  end

  defp newest_id([%Invocation{id: id} | _]), do: id
  defp newest_id([]), do: nil

  defp shown?(%Invocation{} = invocation, genesis) do
    invocation.run_number == genesis.run_number and invocation.state == :completed and
      invocation.model in image_model_ids() and is_binary(invocation.output)
  end

  defp image_model_ids, do: [output_type: :image] |> Panic.Model.all() |> Enum.map(& &1.id)

  defp model(invocation), do: Panic.Model.by_id(invocation.model)

  defp model_name(invocation) do
    case model(invocation) do
      %{name: name} -> name
      nil -> invocation.model
    end
  end

  # an image made from a text prompt is described by it
  defp alt(invocation) do
    case model(invocation) do
      %{input_type: :text} -> invocation.input
      _ -> ""
    end
  end
end
