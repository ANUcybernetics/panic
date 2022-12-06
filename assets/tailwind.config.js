const colors = require("tailwindcss/colors");

module.exports = {
  content: [
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex",
    "../lib/_petal_framework/web/**/*.*ex",
    "./js/**/*.js",
    "../deps/petal_components/**/*.*ex",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        primary: colors.blue,
        secondary: colors.pink,
      },
      fontFamily: {
        'major-mono-display': ['"Major Mono Display"'],
        'noto-color-emoji': ['"Noto Color Emoji"'],
      },
    },
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("@tailwindcss/forms"),
    require("@tailwindcss/line-clamp"),
    require("@tailwindcss/aspect-ratio"),
  ],
};
