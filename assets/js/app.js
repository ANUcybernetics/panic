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
import "@launchscout/autocomplete-input";
import PhoenixCustomEventHook from "phoenix-custom-event-hook";
import live_select from "live_select";

// LiveView hooks

import AudioVisualizer from "./hooks/audio_visualizer";
import TerminalLockoutTimer from "./hooks/terminal_lockout_timer";

const FocusInput = {
  mounted() {
    this.el.addEventListener("click", () => {
      const inputId = this.el.dataset.inputId;
      if (inputId) {
        // Give the autocomplete element a moment to initialize
        setTimeout(() => {
          const autocompleteElement = document.getElementById(inputId);
          if (autocompleteElement) {
            // Try to find the actual input within the autocomplete-input custom element
            const actualInput =
              autocompleteElement.shadowRoot?.querySelector("input") ||
              autocompleteElement.querySelector("input");
            if (actualInput) {
              actualInput.focus();
              actualInput.click(); // Also trigger click to open dropdown
            }
          }
        }, 10);
      }
    });
  },
};

const RunnerCountdown = {
  mounted() {
    this.targetTime = new Date(this.el.dataset.targetTime);
    this.displayEl = this.el.querySelector("#countdown-display");
    this.startCountdown();
  },

  destroyed() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  },

  updated() {
    // Handle updates to the target time
    const newTargetTime = new Date(this.el.dataset.targetTime);
    if (newTargetTime.getTime() !== this.targetTime.getTime()) {
      this.targetTime = newTargetTime;
      if (this.timer) {
        clearInterval(this.timer);
      }
      this.startCountdown();
    }
  },

  startCountdown() {
    const updateDisplay = () => {
      const now = new Date();
      const diff = Math.max(0, Math.floor((this.targetTime - now) / 1000));
      
      if (this.displayEl) {
        this.displayEl.textContent = diff.toString();
      }
      
      if (diff <= 0 && this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }
    };

    // Update immediately
    updateDisplay();

    // Then update every second
    this.timer = setInterval(updateDisplay, 1000);
  }
};

const hooks = {
  AudioVisualizer,
  PhoenixCustomEventHook,
  FocusInput,
  RunnerCountdown,
  TerminalLockoutTimer,
  ...live_select
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

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
