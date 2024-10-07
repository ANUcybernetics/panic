import { Howl } from "howler";
import AudioMotionAnalyzer from "audiomotion-analyzer";

const AudioVisualizer = {
  mounted() {
    this.containerElement = this.el.querySelector(".visualizer-container");
    const audioSrc = this.el.dataset.audioSrc;
    this.playSound(audioSrc);
  },
  updated() {
    const newAudioSrc = this.el.dataset.audioSrc;
    if (newAudioSrc.startsWith("https://fly.storage.tigris.dev")) {
      this.playSound(newAudioSrc);
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
  playSound(audioSrc) {
    if (audioSrc.startsWith("https://fly.storage.tigris.dev")) {
      if (this.sound) {
        this.sound.stop();
        this.sound.unload();
      }
      this.sound = new Howl({
        src: [audioSrc],
        autoplay: true,
        loop: true,
      });
      this.initializeVisualizer();
    }
  },
  initializeVisualizer() {
    this.analyzer = new AudioMotionAnalyzer(this.containerElement, {
      source: this.sound._sounds[0]._node,
      mode: 6,
      frequencyScale: "logarithmic",
      gradient: "prism",
      radial: true,
      spinSpeed: 2,
      mirror: 1,
      showScaleX: false,
      overlay: true,
      showBgColor: true,
      reflexRatio: 0.5,
      reflexAlpha: 1,
      reflexBright: 1,
    });
  },
};

export default AudioVisualizer;
