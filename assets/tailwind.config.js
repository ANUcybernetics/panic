// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/panic_web.ex",
    "../lib/panic_web/**/*.*ex",
    "../deps/live_select/lib/live_select/component.*ex",
  ],
  safelist: [
    "grid-cols-1",
    "grid-cols-2",
    "grid-cols-3",
    "grid-cols-4",
    "grid-cols-5",
    "grid-cols-6",
    "grid-cols-7",
    "grid-cols-8",
    "grid-cols-9",
    "grid-cols-10",
    "grid-cols-11",
    "grid-cols-12",
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      },
      fontFamily: {
        "sometype-mono": ["Sometype Mono", "monospace"],
      },
      keyframes: {
        breathe: {
          "0%, 100%": { opacity: "0.3", fontWeight: "900" },
          "50%": { opacity: "1", fontWeight: "100" },
        },
      },
      animation: {
        breathe: "breathe 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
      },
      // ... (existing theme extensions)
      typography: ({ theme }) => ({
        purple: {
          css: {
            "--tw-prose-body": theme("colors.purple[300]"),
            "--tw-prose-headings": theme("colors.purple[100]"),
            "--tw-prose-lead": theme("colors.purple[300]"),
            "--tw-prose-links": theme("colors.purple[100]"),
            "--tw-prose-bold": theme("colors.purple[100]"),
            "--tw-prose-counters": theme("colors.purple[400]"),
            "--tw-prose-bullets": theme("colors.purple[600]"),
            "--tw-prose-hr": theme("colors.purple[700]"),
            "--tw-prose-quotes": theme("colors.purple[100]"),
            "--tw-prose-quote-borders": theme("colors.purple[700]"),
            "--tw-prose-captions": theme("colors.purple[400]"),
            "--tw-prose-code": theme("colors.purple[100]"),
            "--tw-prose-pre-code": theme("colors.purple[300]"),
            "--tw-prose-pre-bg": "rgb(0 0 0 / 50%)",
            "--tw-prose-th-borders": theme("colors.purple[600]"),
            "--tw-prose-td-borders": theme("colors.purple[700]"),
            "--tw-prose-invert-body": theme("colors.purple[800]"),
            "--tw-prose-invert-headings": theme("colors.purple[900]"),
            "--tw-prose-invert-lead": theme("colors.purple[700]"),
            "--tw-prose-invert-links": theme("colors.purple[900]"),
            "--tw-prose-invert-bold": theme("colors.purple[900]"),
            "--tw-prose-invert-counters": theme("colors.purple[600]"),
            "--tw-prose-invert-bullets": theme("colors.purple[400]"),
            "--tw-prose-invert-hr": theme("colors.purple[300]"),
            "--tw-prose-invert-quotes": theme("colors.purple[900]"),
            "--tw-prose-invert-quote-borders": theme("colors.purple[300]"),
            "--tw-prose-invert-captions": theme("colors.purple[700]"),
            "--tw-prose-invert-code": theme("colors.purple[900]"),
            "--tw-prose-invert-pre-code": theme("colors.purple[100]"),
            "--tw-prose-invert-pre-bg": theme("colors.purple[900]"),
            "--tw-prose-invert-th-borders": theme("colors.purple[300]"),
            "--tw-prose-invert-td-borders": theme("colors.purple[200]"),
            // Add these lines for dark mode specific styles
            color: "var(--tw-prose-body)",
            backgroundColor: "var(--tw-prose-background)",
          },
        },
      }),
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/container-queries"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant("phx-no-feedback", [
        ".phx-no-feedback&",
        ".phx-no-feedback &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ]),
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ]),
    ),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized");
      let values = {};
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"],
      ];
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix;
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        });
      });
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "");
            let size = theme("spacing.6");
            if (name.endsWith("-mini")) {
              size = theme("spacing.5");
            } else if (name.endsWith("-micro")) {
              size = theme("spacing.4");
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            };
          },
        },
        { values },
      );
    }),
  ],
};
