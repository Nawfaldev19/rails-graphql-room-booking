import { useEffect, useState, useSyncExternalStore } from 'react';

/** The current time, refreshed every minute, so "today" and "past" stay true. */
export function useNow(intervalMs = 60_000): Date {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = window.setInterval(() => {
      setNow(new Date());
    }, intervalMs);
    return () => {
      window.clearInterval(timer);
    };
  }, [intervalMs]);
  return now;
}

/** Whether a CSS media query matches, kept up to date as the window changes. */
export function useMediaQuery(query: string): boolean {
  return useSyncExternalStore(
    (notify) => {
      const list = window.matchMedia(query);
      list.addEventListener('change', notify);
      return () => {
        list.removeEventListener('change', notify);
      };
    },
    () => window.matchMedia(query).matches,
    () => false,
  );
}

/** A value that follows its source after a quiet period, for search-as-you-type calls. */
export function useDebounced<Value>(value: Value, delayMs = 350): Value {
  const [settled, setSettled] = useState(value);
  useEffect(() => {
    const timer = window.setTimeout(() => {
      setSettled(value);
    }, delayMs);
    return () => {
      window.clearTimeout(timer);
    };
  }, [value, delayMs]);
  return settled;
}

/** Offers text as a file download without a round trip to the server. */
export function downloadText(filename: string, mediaType: string, text: string): void {
  const url = URL.createObjectURL(new Blob([text], { type: mediaType }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}
