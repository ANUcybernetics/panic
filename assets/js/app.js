// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import live_select from "live_select";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const hooks = {
  TerminalLockoutTimer: {
    mounted() {
      this.timer = setInterval(() => {
        this.updateDisplay();
      }, 1000);
    },

    destroyed() {
      clearInterval(this.timer);
      this.timer = null;
    },

    updateDisplay() {
      const readyAt = new Date(this.el.dataset.readyAt);
      const now = new Date();
      const timeLeft = Math.max(0, Math.ceil((readyAt - now) / 1000));
      if (timeLeft > 0) {
        this.el.placeholder = `Starting up... re-promptible in ${timeLeft} second${timeLeft !== 1 ? "s" : ""}`;
        this.el.disabled = true;
        this.el.value = "";
      } else {
        this.el.placeholder = "Ready for new prompt";
        this.el.disabled = false;
        this.el.focus();
      }
    },
  },
  ...live_select,
};

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// code from https://fly.io/phoenix-files/phoenix-dev-blog-server-logs-in-the-browser-console/
window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
  // Enable server log streaming to client.
  // Disable with reloader.disableServerLogs()
  reloader.enableServerLogs();
  window.liveReloader = reloader;
});
