// AudioVisualizer hook
import AudioMotionAnalyzer from "audiomotion-analyzer";

const AudioVisualizer = {
  mounted() {
    this.audioElement = this.el.querySelector("audio");
    this.containerElement = this.el.querySelector(".visualizer-container");

    if (this.audioElement && this.containerElement) {
      this.initializeVisualizer();
    }
  },

  destroyed() {
    if (this.analyzer) {
      this.analyzer.destroy();
    }
  },

  initializeVisualizer() {
    this.analyzer = new AudioMotionAnalyzer(this.containerElement, {
      source: this.audioElement,
      height: 200,
      width: 400,
      mode: 2,
      smoothing: 0.7,
      frequencyScale: "logarithmic",
      fillAlpha: 0.7,
      gradient: "prism",
    });
  },
};

export default AudioVisualizer;
