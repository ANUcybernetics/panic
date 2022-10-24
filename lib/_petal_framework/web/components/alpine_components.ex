defmodule PetalFramework.Components.AlpineComponents do
  use Phoenix.Component

  # The required javascript for these components. Run this on any page using the components (above the components).
  def js_setup(assigns) do
    ~H"""
    <script>
      window.maybeTruncate = function(lines) {
        let twClass;

        switch (lines) {
          case 1:
            twClass = "line-clamp-1";
            break;
          case 2:
            twClass = "line-clamp-2";
            break;
          case 3:
            twClass = "line-clamp-3";
            break;
          case 4:
            twClass = "line-clamp-4";
            break;
          case 5:
            twClass = "line-clamp-5";
            break;
          default:
            twClass = "line-clamp-3";
        }

        return {
          truncated: true,
          truncatable: false,
          twClass: twClass,

          init() {
            this.$nextTick(() => {
              this.setTruncate(this.$refs.text);
            })
          },
          setTruncate(element) {
            if (
              element.offsetHeight < element.scrollHeight ||
              element.offsetWidth < element.scrollWidth
            ) {
              this.truncatable = true;
            } else {
              this.truncatable = false;
            }
          },
        };
      }
    </script>
    """
  end

  @doc """
  When you have a lot text you might want to hide most of it and render a "Show more" link.
  This does that with Alpine.

  Usage:
      <AlpineComponents.truncate lines={5}>
        <%= inspect(job.errors) %>
      </AlpineComponents.truncate>
  """

  attr :lines, :integer, default: 3
  slot(:inner_block)

  def truncate(assigns) do
    ~H"""
    <div x-data={"maybeTruncate(#{@lines})"}>
      <div x-ref="text" x-bind:class="truncated ? twClass : ''">
        <%= render_slot(@inner_block) %>
      </div>
      <a
        href="#"
        x-show="truncatable"
        class="underline"
        x-on:click="truncated = !truncated"
        x-text="truncated ? 'Show more' : 'Show less'"
      >
      </a>
    </div>
    """
  end
end
