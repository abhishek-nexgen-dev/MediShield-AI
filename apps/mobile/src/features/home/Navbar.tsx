import { useState } from 'react';

import { PublicLink } from '@/components/layout/PublicLink';

import { Brand } from './Brand';
import { Icon } from './Icon';
import { container, primaryButton, secondaryButton } from './styles';
import { isTheme, type HomeTheme } from './theme';

const navigation = [
  { href: '#home', label: 'Home' },
  { href: '#about', label: 'About' },
  { href: '#features', label: 'Features' },
  { href: '#how-it-works', label: 'How It Works' },
  { href: '#hospitals', label: 'For Hospitals' },
  { href: '#contact', label: 'Contact' },
];

type NavbarProps = {
  sectionBase: '' | '/';
  theme: HomeTheme;
  onThemeChange: (theme: HomeTheme) => void;
};

export function Navbar({ sectionBase, theme, onThemeChange }: NavbarProps) {
  const [menuOpen, setMenuOpen] = useState(false);

  const links = navigation.map(({ href, label }) => (
    <a key={href} href={sectionBase + href} className="whitespace-nowrap text-sm font-medium text-secondary no-underline hover:text-primary" onClick={() => setMenuOpen(false)}>{label}</a>
  ));

  return (
    <header className="sticky top-0 z-[4] border-b border-border bg-surface">
      <div className={`${container} flex min-h-16 items-center justify-between gap-2 sm:min-h-[4.75rem] sm:gap-4`}>
        <Brand href={sectionBase || '#home'} />
        <nav className="hidden items-center gap-[clamp(.7rem,1.55vw,1.5rem)] min-[1073px]:flex [&_a]:py-2.5" aria-label="Main navigation">{links}</nav>
        <div className="flex items-center gap-1.5">
          <label className="relative inline-flex min-h-11 items-center rounded-lg border border-border pl-2.5 text-secondary after:pointer-events-none after:absolute after:right-[.52rem] after:top-[45%] after:size-1.5 after:rotate-45 after:border-b after:border-r after:border-current after:content-['']">
            <Icon name="theme" size={17} />
            <select
              aria-label="Color theme"
              className="min-h-[2.625rem] cursor-pointer appearance-none rounded-lg bg-transparent pl-1.5 pr-5 text-[.8125rem] text-secondary [&_option]:bg-surface [&_option]:text-ink"
              value={theme}
              onChange={(event) => {
                const value = event.currentTarget.value;
                if (isTheme(value)) onThemeChange(value);
              }}>
              <option value="system">System</option>
              <option value="light">Light</option>
              <option value="dark">Dark</option>
            </select>
          </label>
          <div className="hidden items-center gap-1.5 min-[1073px]:flex">
            <PublicLink href="/login" className="inline-flex min-h-11 items-center rounded-lg px-3 py-2.5 text-sm font-semibold text-ink no-underline hover:bg-subtle">Log In</PublicLink>
            <PublicLink href="/register-hospital" className={primaryButton}>Register Hospital</PublicLink>
          </div>
          <button
            className="inline-flex size-11 cursor-pointer items-center justify-center rounded-lg border border-border bg-surface text-ink hover:bg-subtle min-[1073px]:hidden"
            type="button"
            aria-label={menuOpen ? 'Close navigation' : 'Open navigation'}
            aria-expanded={menuOpen}
            aria-controls="mobile-home-navigation"
            onClick={() => setMenuOpen((open) => !open)}>
            <Icon name={menuOpen ? 'close' : 'menu'} size={22} />
          </button>
        </div>
      </div>
      <nav className={`${container} ${menuOpen ? 'grid' : 'hidden'} pb-4 pt-1 min-[1073px]:hidden [&>a]:border-t [&>a]:border-border [&>a]:py-2.5`} id="mobile-home-navigation" aria-label="Mobile navigation" hidden={!menuOpen}>
        {links}
        <div className="mt-2 flex flex-wrap gap-2">
          <PublicLink href="/login" className={secondaryButton} onClick={() => setMenuOpen(false)}>Log In</PublicLink>
          <PublicLink href="/register-hospital" className={primaryButton} onClick={() => setMenuOpen(false)}>Register Hospital</PublicLink>
        </div>
      </nav>
    </header>
  );
}
