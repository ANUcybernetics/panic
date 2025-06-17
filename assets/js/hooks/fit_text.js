// FitText hook - Uses CSS custom properties for cleaner font size management
const FitText = {
  mounted() {
    this.findTextElements();
    this.storeOriginalSizes();
    this.resizeText();

    // Use ResizeObserver to handle dynamic content changes
    this.resizeObserver = new ResizeObserver(() => {
      this.resizeText();
    });
    this.resizeObserver.observe(this.el);

    // Also listen for content changes
    this.mutationObserver = new MutationObserver(() => {
      // Re-find text elements in case DOM structure changed
      this.findTextElements();
      this.storeOriginalSizes();
      this.resizeText();
    });
    this.mutationObserver.observe(this.el, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  },

  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
    }
  },

  findTextElements() {
    // Find all elements that have text content and could need resizing
    this.textElements = Array.from(this.el.querySelectorAll("*")).filter(
      (el) => {
        const hasText = el.textContent && el.textContent.trim();
        const isLeafTextNode =
          hasText &&
          !Array.from(el.children).some(
            (child) => child.textContent && child.textContent.trim(),
          );
        return isLeafTextNode;
      },
    );

    // If no specific text elements found, use the container itself
    if (
      this.textElements.length === 0 &&
      this.el.textContent &&
      this.el.textContent.trim()
    ) {
      this.textElements = [this.el];
    }
  },

  storeOriginalSizes() {
    this.textElements.forEach((el) => {
      if (!el.dataset.originalFontSize) {
        const computedStyle = getComputedStyle(el);
        el.dataset.originalFontSize = parseFloat(computedStyle.fontSize);
      }
    });
  },

  resizeText() {
    if (this.textElements.length === 0) return;

    // Reset to original sizes
    this.textElements.forEach((el) => {
      const originalSize = parseFloat(el.dataset.originalFontSize);
      el.style.setProperty("--fit-text-size", `${originalSize}px`);
    });

    const minFontSize = 8; // Minimum readable size
    let maxOriginalSize = Math.max(
      ...this.textElements.map((el) => parseFloat(el.dataset.originalFontSize)),
    );

    let currentScale = 1;

    // Keep shrinking until text fits or we hit minimum
    while (
      currentScale * maxOriginalSize > minFontSize &&
      this.isTextOverflowing()
    ) {
      currentScale -= 0.05; // Smaller increments for smoother scaling
      this.textElements.forEach((el) => {
        const originalSize = parseFloat(el.dataset.originalFontSize);
        const newSize = originalSize * currentScale;
        el.style.setProperty("--fit-text-size", `${newSize}px`);
      });
    }
  },

  isTextOverflowing() {
    // Check if the container itself is overflowing
    const containerOverflow =
      this.el.scrollHeight > this.el.clientHeight ||
      this.el.scrollWidth > this.el.clientWidth;

    // Also check individual text elements
    const textOverflow = this.textElements.some((el) => {
      return (
        el.scrollHeight > el.clientHeight || el.scrollWidth > el.clientWidth
      );
    });

    return containerOverflow || textOverflow;
  },
};
