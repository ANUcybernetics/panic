import { Howl } from "howler";
import AudioMotionAnalyzer from "audiomotion-analyzer";

const AudioVisualizer = {
  mounted() {
    this.containerElement = this.el.querySelector(".visualizer-container");
    this.audioSrc = this.el.dataset.audioSrc;
    this.playSound();
  },
  updated() {
    const newAudioSrc = this.el.dataset.audioSrc;
    if (newAudioSrc !== this.audioSrc) {
      this.audioSrc = newAudioSrc;
      this.playSound();
    }
  },
  destroyed() {
    if (this.analyzer) {
      this.analyzer.destroy();
    }
    if (this.sound) {
      this.sound.stop();
      this.sound.unload();
    }
  },
  playSound() {
    if (this.sound) {
      this.sound.stop();
      this.sound.unload();
    }
    this.sound = new Howl({
      src: [this.audioSrc],
      autoplay: true,
      loop: true,
      onload: () => {
        this.initializeVisualizer();
      },
    });
  },

  initializeVisualizer() {
    // Destroy existing analyzer to prevent memory leaks
    if (this.analyzer) {
      this.analyzer.destroy();
    }

    if (this.sound && this.sound._sounds[0] && this.sound._sounds[0]._node) {
      this.analyzer = new AudioMotionAnalyzer(this.containerElement, {
        source: this.sound._sounds[0]._node,
        mode: 8, // Full octave bands (fewer bars for better performance)
        frequencyScale: "logarithmic",
        gradient: "rainbow",
        radial: true,
        spinSpeed: 10 * Math.random() + -5,
        mirror: 1,
        showScaleX: false,
        overlay: true,
        showBgColor: true,
        bgAlpha: 0.7,
        // Performance optimizations for low-powered hardware
        fftSize: 4096, // Reduced from default 8192 for better performance
        maxFPS: 30, // Limit frame rate to reduce CPU usage
        loRes: true, // Enable low resolution mode (halves pixel ratio)
        smoothing: 0.3, // Faster response, less CPU-intensive smoothing
        showPeaks: false, // Disable peaks to reduce rendering complexity
        reflexRatio: 0, // Disable reflection effects for better performance
      });

      // Fix canvas sizing issue with loRes mode - ensure canvas fills container
      if (this.analyzer && this.analyzer.canvas) {
        const canvas = this.analyzer.canvas;
        const containerRect = this.containerElement.getBoundingClientRect();
        canvas.style.width = "100%";
        canvas.style.height = "100%";
      }
    }
  },
};

export default AudioVisualizer;
