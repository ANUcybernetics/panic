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
    if (
      newAudioSrc.startsWith("https://fly.storage.tigris.dev") &&
      newAudioSrc !== this.audioSrc
    ) {
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
    if (this.sound && this.sound._sounds[0] && this.sound._sounds[0]._node) {
      this.analyzer = new AudioMotionAnalyzer(this.containerElement, {
        source: this.sound._sounds[0]._node,
        mode: 6,
        frequencyScale: "logarithmic",
        gradient: "rainbow",
        radial: true,
        spinSpeed: 10 * Math.random() + -5,
        mirror: 1,
        showScaleX: false,
        overlay: true,
        showBgColor: true,
        bgAlpha: 0.7,
        reflexRatio: 0.5,
        reflexAlpha: 1,
        reflexBright: 1,
      });
    }
  },
};

export default AudioVisualizer;
