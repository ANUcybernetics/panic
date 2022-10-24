// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import Hooks from "./hooks";
import { onDocReady } from "../_petal_framework/js/lib/util";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
      }
    },
  },
  params: { _csrf_token: csrfToken },
});

/*
  The following code allows hooks to be run in dead views.
  To allow a hook to run in a dead view, add the following to the hook:

      function MyHook() {
        deadViewCompatible: true,

        mounted() {
          // do stuff
        }
      }

  Only works with hooks that don't communicate with a live view.
*/
onDocReady(() => {
  if (!liveSocket.boundTopLevelEvents) {
    [...document.querySelectorAll("[phx-hook]")].map((hookEl) => {
      let hookName = hookEl.getAttribute("phx-hook");
      let hook = Hooks[hookName];

      if (hook && hook.deadViewCompatible) {
        let mountedFn = hook.mounted.bind({ ...hook, el: hookEl });
        mountedFn();
      }
    });
  }
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
let topBarScheduled = undefined;
window.addEventListener("phx:page-loading-start", () => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 120);
  }
});
window.addEventListener("phx:page-loading-stop", () => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  topbar.hide();
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
