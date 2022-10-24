import loadExternalFile from "../lib/load-external-file";

/*
  Will display a UTC timestamp in the user's browser's timezone

  You can pass in an optional options attribute with options JSON-encoded from:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat

  <time phx-hook="LocalTimeHook" id={id} class="invisible" data-options={Jason.encode!(options)}>
    <%= date %>
  </time>

  For a HEEX component, see local_time.ex
*/
const LocalTimeHook = {
  deadViewCompatible: true,
  mounted() {
    this.updated();
  },
  updated() {
    loadExternalFile([
      "https://cdnjs.cloudflare.com/ajax/libs/timeago.js/4.0.2/timeago.min.js",
    ]).then(() => {
      let dt = new Date(this.el.textContent.trim());
      let options = JSON.parse(this.el.dataset.options);
      let formatted;

      if (options["relative"] === true) {
        formatted = timeago.format(dt);
      } else {
        formatted = new Intl.DateTimeFormat("default", options).format(dt);
      }

      this.el.textContent = formatted;
      this.el.classList.remove("invisible");
    });
  },
};

export default LocalTimeHook;
