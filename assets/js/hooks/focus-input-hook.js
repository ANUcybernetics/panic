/*
  Docs: https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks

  Usage: when using phx-hook, a unique DOM ID must always be set.

      <div phx-hook="FocusInputHook" id="someUniqueId"></div>
*/

const FocusInputHook = {
  // This function runs when the element has been added to the DOM and its server LiveView has finished mounting
  mounted() {
    // How to listen to events from the live view
    this.handleEvent("focus_input", ({ id }) => {
      let el = document.getElementById(id);

      if (el){
        el.focus();
      }
    });

    /*
    How to send events from the live view:

    # Elixir code:
    push_event(socket, "some_event", %{var1: 100})
    */
  },
};

export default FocusInputHook;
