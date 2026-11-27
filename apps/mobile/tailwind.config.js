const plugin = require('tailwindcss/plugin');

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: { relative: true, files: ['./src/**/*.{js,jsx,ts,tsx}'] },
  presets: [require('nativewind/preset')],
  darkMode: 'class',
  corePlugins: { preflight: false },
  theme: {
    extend: {
      colors: {
        canvas: 'var(--home-canvas)',
        surface: 'var(--home-surface)',
        subtle: 'var(--home-subtle)',
        ink: 'var(--home-ink)',
        secondary: 'var(--home-secondary)',
        muted: 'var(--home-muted)',
        border: 'var(--home-border)',
        control: 'var(--home-control)',
        primary: 'var(--home-primary)',
        'on-primary': 'var(--home-on-primary)',
        'primary-hover': 'var(--home-primary-hover)',
        accent: 'var(--home-accent)',
        'on-accent': 'var(--home-on-accent)',
        focus: 'var(--home-focus)',
      },
      fontFamily: {
        geist: ['Geist', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        symbols: ['Home Symbols'],
      },
    },
  },
  plugins: [
    plugin(({ addBase }) => {
      addBase({
        '@font-face': [
          {
            fontFamily: 'Geist',
            src: "url('/fonts/Geist-Variable.woff2') format('woff2')",
            fontWeight: '100 900',
            fontDisplay: 'swap',
          },
          {
            fontFamily: 'Home Symbols',
            src: "url('/fonts/HomeSymbols.woff2') format('woff2')",
            fontDisplay: 'block',
          },
        ],
        // Scope the browser reset to the homepage so existing Expo screens keep their defaults.
        ':where(.home-page, .home-page *, .home-page *::before, .home-page *::after)': {
          boxSizing: 'border-box',
          borderWidth: '0',
          borderStyle: 'solid',
          borderColor: 'transparent',
        },
        ':where(.home-page) :where(h1, h2, h3, p, figure, dl, dd, ul, ol)': { margin: '0' },
        ':where(.home-page) :where(button, select)': { fontFamily: 'inherit' },
        ':where(.home-page) :focus-visible': {
          outline: '2px solid var(--home-focus)',
          outlineOffset: '3px',
        },
      });
    }),
  ],
};
