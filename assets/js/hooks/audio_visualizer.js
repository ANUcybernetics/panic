import AudioMotionAnalyzer from "audiomotion-analyzer";

// Shared Web Audio Context to prevent exhaustion
let sharedAudioContext = null;
let activeInstances = 0;

function getSharedAudioContext() {
  if (!sharedAudioContext || sharedAudioContext.state === 'closed') {
    sharedAudioContext = new AudioContext();
  }
  return sharedAudioContext;
}

const AudioVisualizer = {
  mounted() {
    this.containerElement = this.el.querySelector(".visualizer-container");
    this.audioSrc = this.el.dataset.audioSrc;
    this.isDestroyed = false;
    activeInstances++;
    this.playSound();
    
    // Add visibility change handler to pause/resume when hidden
    this.handleVisibilityChange = () => {
      if (document.hidden && this.audioElement && !this.audioElement.paused) {
        this.audioElement.pause();
      } else if (!document.hidden && this.audioElement && this.audioElement.paused) {
        this.audioElement.play();
      }
    };
    document.addEventListener('visibilitychange', this.handleVisibilityChange);
  },
  
  updated() {
    const newAudioSrc = this.el.dataset.audioSrc;
    if (newAudioSrc !== this.audioSrc) {
      this.audioSrc = newAudioSrc;
      this.playSound();
    }
  },
  
  destroyed() {
    this.isDestroyed = true;
    this.cleanup();
    document.removeEventListener('visibilitychange', this.handleVisibilityChange);
    activeInstances--;
    
    // Only close the shared context if no instances are using it
    if (activeInstances === 0 && sharedAudioContext && sharedAudioContext.state !== 'closed') {
      sharedAudioContext.close();
      sharedAudioContext = null;
    }
  },
  
  cleanup() {
    // Destroy analyzer first
    if (this.analyzer) {
      try {
        this.analyzer.destroy();
      } catch (e) {
        console.warn("Error destroying analyzer:", e);
      }
      this.analyzer = null;
    }
    
    // Clean up audio element
    if (this.audioElement) {
      try {
        this.audioElement.pause();
        this.audioElement.src = "";
        this.audioElement.load();
      } catch (e) {
        console.warn("Error cleaning up audio element:", e);
      }
      this.audioElement = null;
    }
    
    // Disconnect audio source but don't close context (it's shared)
    if (this.audioSource) {
      try {
        this.audioSource.disconnect();
      } catch (e) {
        console.warn("Error disconnecting audio source:", e);
      }
      this.audioSource = null;
    }
  },
  
  playSound() {
    if (this.isDestroyed) return;
    
    // Clean up previous instance
    this.cleanup();
    
    // Create audio element
    this.audioElement = new Audio(this.audioSrc);
    this.audioElement.loop = true;
    this.audioElement.crossOrigin = "anonymous";
    
    // Use shared audio context
    const audioContext = getSharedAudioContext();
    this.audioSource = audioContext.createMediaElementSource(this.audioElement);
    this.audioSource.connect(audioContext.destination);
    
    // Handle autoplay policies
    this.audioElement.play().catch(e => {
      console.warn("Autoplay blocked, will retry on user interaction:", e);
      const resumeAudio = () => {
        audioContext.resume();
        this.audioElement.play();
        document.removeEventListener('click', resumeAudio);
      };
      document.addEventListener('click', resumeAudio);
    });
    
    // Initialize visualizer once audio is ready
    this.audioElement.addEventListener('canplay', () => {
      if (!this.isDestroyed) {
        this.initializeVisualizer();
      }
    }, { once: true });
    
    // Error handling with better recovery
    this.audioElement.addEventListener('error', (e) => {
      console.error("Audio element error:", e);
      // Don't retry immediately to avoid loops
      setTimeout(() => {
        if (!this.isDestroyed && this.audioElement) {
          // Try to reload from scratch
          this.playSound();
        }
      }, 5000);
    });
  },

  initializeVisualizer() {
    if (this.isDestroyed) return;
    
    if (this.analyzer) {
      try {
        this.analyzer.destroy();
      } catch (e) {
        console.warn("Error destroying existing analyzer:", e);
      }
      this.analyzer = null;
    }

    requestAnimationFrame(() => {
      if (this.isDestroyed) return;
      
      if (this.audioSource) {
        try {
          this.analyzer = new AudioMotionAnalyzer(this.containerElement, {
            source: this.audioSource,
            mode: 8,
            frequencyScale: "logarithmic",
            gradient: "rainbow",
            radial: true,
            spinSpeed: 10 * Math.random() + -5,
            mirror: 1,
            showScaleX: false,
            overlay: true,
            showBgColor: true,
            bgAlpha: 0.7,
            // Performance optimizations for Raspberry Pi
            fftSize: 2048,
            maxFPS: 24,
            loRes: true,
            smoothing: 0.5,
            showPeaks: false,
            reflexRatio: 0,
          });

          if (this.analyzer && this.analyzer.canvas) {
            const canvas = this.analyzer.canvas;
            canvas.style.width = "100%";
            canvas.style.height = "100%";
            canvas.style.transform = "none";
          }
        } catch (e) {
          console.error("Error creating analyzer:", e);
        }
      }
    });
  },
};

export default AudioVisualizer;
