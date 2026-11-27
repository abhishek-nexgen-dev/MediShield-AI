import type { HomeTheme } from './theme';

export const container = 'mx-auto w-[calc(100%-2rem)] max-w-[76rem] sm:w-[calc(100%-3rem)]';

const button =
  'inline-flex min-h-11 cursor-pointer items-center justify-center gap-2 rounded-lg border px-4 py-2.5 text-center text-sm font-semibold leading-tight no-underline';

export const primaryButton = `${button} border-primary bg-primary text-on-primary hover:border-primary-hover hover:bg-primary-hover`;
export const secondaryButton = `${button} border-control bg-surface text-ink hover:bg-subtle`;

const colorSchemes: Record<HomeTheme, string> = {
  light: '[color-scheme:light]',
  dark: '[color-scheme:dark]',
  system: '[color-scheme:light_dark]',
};

const homeTheme = [
  '[--home-canvas:light-dark(#f6f8f7,#0b1110)]',
  '[--home-surface:light-dark(#ffffff,#121c19)]',
  '[--home-subtle:light-dark(#f0f4f2,#192622)]',
  '[--home-ink:light-dark(#13231d,#edf5f1)]',
  '[--home-secondary:light-dark(#42554c,#b9cbc2)]',
  '[--home-muted:light-dark(#52655b,#9cb0a5)]',
  '[--home-border:light-dark(#dce5df,#30443a)]',
  '[--home-control:light-dark(#788c80,#738d80)]',
  '[--home-primary:light-dark(#047857,#34d399)]',
  '[--home-on-primary:light-dark(#ffffff,#022c22)]',
  '[--home-primary-hover:light-dark(#065f46,#6ee7b7)]',
  '[--home-accent:light-dark(#ecfdf5,#123b2c)]',
  '[--home-on-accent:light-dark(#065f46,#a7f3d0)]',
  '[--home-focus:light-dark(#047857,#6ee7b7)]',
].join(' ');

export function homepageClasses(theme: HomeTheme) {
  return `home-page h-[100dvh] overflow-x-hidden overflow-y-auto scroll-pt-[5.5rem] bg-canvas font-geist leading-relaxed text-ink ${colorSchemes[theme]} ${homeTheme}`;
}
