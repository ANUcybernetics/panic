// Drives the native <dialog> rendered by CoreComponents.modal/1: data-show
// opens it with showModal(), and a close the user makes (Esc, the daisyUI
// backdrop form, the close button) runs the data-cancel JS command.
const Modal = {
  mounted() {
    // showModal() sets these client-side; stop LiveView patches removing them
    this.js().ignoreAttributes(this.el, ["open", "aria-label"]);

    const heading = this.el.querySelector("h1, h2");
    if (heading) this.el.setAttribute("aria-label", heading.textContent.trim());

    this.el.addEventListener("close", () => {
      if (this.closingFromServer) {
        this.closingFromServer = false;
      } else {
        this.js().exec(this.el.dataset.cancel);
      }
    });

    this.sync();
  },

  updated() {
    this.sync();
  },

  sync() {
    const show = this.el.dataset.show === "true";
    if (show && !this.el.open) {
      this.el.showModal();
    } else if (!show && this.el.open) {
      this.closingFromServer = true;
      this.el.close();
    }
  },
};

export default Modal;
