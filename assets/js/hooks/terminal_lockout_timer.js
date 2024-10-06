// TerminalLockoutTimer hook
const TerminalLockoutTimer = {
  mounted() {
    this.updateDisplay();
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
      // this.el.focus();
    }
  },
};

export default TerminalLockoutTimer;
