import { useEffect, useState } from 'react';

const storageKey = 'medishield.home.theme';

export type HomeTheme = 'system' | 'light' | 'dark';

export function isTheme(value: string | null): value is HomeTheme {
  return value === 'system' || value === 'light' || value === 'dark';
}

export function useHomeTheme() {
  const [theme, setTheme] = useState<HomeTheme>('system');

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(storageKey);
      if (isTheme(saved)) setTheme(saved);
    } catch {
      // The system theme still works when browser storage is disabled.
    }
  }, []);

  function changeTheme(value: HomeTheme) {
    setTheme(value);
    try {
      window.localStorage.setItem(storageKey, value);
    } catch {
      // The preference still applies for this visit.
    }
  }

  return [theme, changeTheme] as const;
}
