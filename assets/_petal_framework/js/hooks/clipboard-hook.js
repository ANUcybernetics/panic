/*
  Usage:
    <button
      type="button"
      phx-hook="ClipboardHook"
      data-content="What will be copied to the clipboard"
      id="something_unique"
    >
      <div class="before-copied"><Outline.clipboard_list class="w-5 h-5 text-slate-500 hover:text-slate-400 dark:text-slate-400 dark:hover:text-slate-300" /></div>
      <div class="after-copied hidden">Copied!</div>
    </button>
*/

const ClipboardHook = {
  deadViewCompatible: true,

  mounted() {
    this.init(this.el);
  },

  updated() {
    this.init(this.el);
  },

  init(el) {
    if (navigator.clipboard) {
      el.addEventListener("click", function () {
        copyToClipboard(el);
        toggleState(el);
        setTimeout(() => {
          toggleState(el);
        }, 3000);
      });
    }
  },
};

function toggleState(el) {
  el.querySelector(".before-copied").classList.toggle("hidden");
  el.querySelector(".after-copied").classList.toggle("hidden");
}

function copyToClipboard(el) {
  let textToCopy = el.dataset.content;

  if (navigator.clipboard) {
    navigator.clipboard.writeText(textToCopy);
  } else {
    alert(
      "Sorry, your browser does not support clipboard copy. Please upgrade it."
    );
  }
}

export default ClipboardHook;
