const TerminalLockoutTimer = {
  mounted() {
    this.startTimer();
  },

  updated() {
    this.startTimer();
  },

  destroyed() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  },

  startTimer() {
    if (this.timer) {
      clearInterval(this.timer);
    }
    this.updateDisplay();
    this.timer = setInterval(() => this.updateDisplay(), 1000);
  },

  updateDisplay() {
    const readyAt = this.el.dataset.readyAt;
    if (!readyAt) {
      this.el.placeholder = "Ready for new input";
      this.el.disabled = false;
      return;
    }
    const timeLeft = Math.max(0, Math.ceil((new Date(readyAt) - new Date()) / 1000));
    if (timeLeft > 0) {
      this.el.placeholder = `${timeLeft} second${timeLeft !== 1 ? "s" : ""} until ready for new input`;
      this.el.disabled = true;
      this.el.value = "";
    } else {
      this.el.placeholder = "Ready for new input";
      if (this.el.disabled) {
        this.el.disabled = false;
        this.el.focus();
      }
    }
  },
};

export default TerminalLockoutTimer;
