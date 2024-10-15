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
      this.el.placeholder = `${timeLeft} second${timeLeft !== 1 ? "s" : ""} until ready for new input`;
      this.el.disabled = true;
      this.el.value = "";
    } else {
      if (this.el.disabled) {
        this.el.focus();
      }
      this.el.placeholder = "Ready for new input";
      this.el.disabled = false;
    }
  },
};

export default TerminalLockoutTimer;
