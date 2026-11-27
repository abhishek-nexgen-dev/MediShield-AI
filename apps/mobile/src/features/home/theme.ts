import { useState, useSyncExternalStore } from 'react';

const storageKey = 'medishield.home.theme';
const themeChanged = 'medishield-theme-changed';

export type HomeTheme = 'system' | 'light' | 'dark';

export function isTheme(value: string | null): value is HomeTheme {
  return value === 'system' || value === 'light' || value === 'dark';
}

function readTheme(): HomeTheme {
  try {
    const saved = window.localStorage.getItem(storageKey);
    if (isTheme(saved)) return saved;
  } catch {
    // Storage may be blocked by browser preferences.
  }
  return 'system';
}

function subscribeToTheme(onChange: () => void) {
  window.addEventListener('storage', onChange);
  window.addEventListener(themeChanged, onChange);
  return () => {
    window.removeEventListener('storage', onChange);
    window.removeEventListener(themeChanged, onChange);
  };
}

export function useHomeTheme() {
  const saved = useSyncExternalStore(subscribeToTheme, readTheme, () => 'system' as const);
  const [temporaryTheme, setTemporaryTheme] = useState<HomeTheme>();

  function changeTheme(value: HomeTheme) {
    try {
      window.localStorage.setItem(storageKey, value);
      setTemporaryTheme(undefined);
      window.dispatchEvent(new Event(themeChanged));
    } catch {
      setTemporaryTheme(value);
    }
  }

  return [temporaryTheme ?? saved, changeTheme] as const;
}
