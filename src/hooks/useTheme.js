import { useCallback, useState } from 'react';

const STORAGE_KEY = 'ff-theme';

function currentTheme() {
  return document.documentElement.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
}

/**
 * Reads the theme the inline boot script already applied to <html>, and keeps
 * the attribute + localStorage in sync when the user toggles. Dark — the main
 * site's navy palette — is the default; light is opt-in.
 */
export default function useTheme() {
  const [theme, setTheme] = useState(currentTheme);

  const toggleTheme = useCallback(() => {
    setTheme((prev) => {
      const next = prev === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      try {
        localStorage.setItem(STORAGE_KEY, next);
      } catch (e) { /* private mode — just session */ }
      return next;
    });
  }, []);

  return { theme, toggleTheme };
}
