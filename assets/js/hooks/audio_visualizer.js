import { Howl } from "howler";
import AudioMotionAnalyzer from "audiomotion-analyzer";

const AudioVisualizer = {
  mounted() {
    this.containerElement = this.el.querySelector(".visualizer-container");
    const audioSrc = this.el.dataset.audioSrc;

    if (this.containerElement && audioSrc) {
      this.sound = new Howl({
        src: [audioSrc],
        autoplay: true,
        loop: true,
      });

      this.initializeVisualizer();
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
      reflexRatio: 0.1,
      reflexAlpha: 0.25,
      overlay: true,
      showBgColor: true,
      reflexRatio: 0.5,
      reflexAlpha: 1,
      reflexBright: 1,
    });
  },
};

export default AudioVisualizer;
