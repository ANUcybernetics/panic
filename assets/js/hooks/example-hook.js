/*
  Docs: https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks

  Usage: when using phx-hook, a unique DOM ID must always be set.

      <div phx-hook="ExampleHook" id="someUniqueId"></div>
*/

const ExampleHook = {
  // This function runs when the element has been added to the DOM and its server LiveView has finished mounting
  mounted() {
    let currentEl = this.el;

    // How to push an event to the live view:
    this.pushEvent("some_event", payload, (reply, ref) =>
      console.log(reply, ref)
    );

    /*
    How to handle an event in the live view (elixir code):

    # Elixir code:
    @impl true
    def handle_event("some_event", params, socket) do
      {:noreply, socket}
    end
    */

    // How to listen to events from the live view
    this.handleEvent("some_event", ({ var1 }) => {
      // do something with var1
    });

    /*
    How to send events from the live view:

    # Elixir code:
    push_event(socket, "some_event", %{var1: 100})
    */
  },

  // This function runs when the element is about to be updated in the DOM. Note: any call here must be synchronous as the operation cannot be deferred or cancelled.
  beforeUpdate() {},

  // This function runs when the element has been updated in the DOM by the server
  updated() {},

  // This function runs when the element has been removed from the page, either by a parent update, or by the parent being removed entirely
  destroyed() {},

  // This function runs when the element's parent LiveView has disconnected from the server
  disconnected() {},

  // This function runs when the element's parent LiveView has reconnected to the server
  reconnected() {},
};

export default ExampleHook;
