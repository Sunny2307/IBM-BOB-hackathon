import { useEffect, useState } from "react";
import { ApiError } from "../api/client";

export interface AsyncResult<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  isFallback: boolean;
}

/**
 * Fetches data from the real API. If the request fails (backend not running,
 * network error, non-2xx response), falls back to local mock data so the UI
 * stays demo-able. `isFallback` is surfaced so pages can show a small
 * "demo data" indicator instead of silently pretending it's live.
 */
export function useAsyncData<T>(
  fetcher: () => Promise<T>,
  fallback: () => T,
  deps: unknown[],
): AsyncResult<T> {
  const [state, setState] = useState<AsyncResult<T>>({
    data: null,
    loading: true,
    error: null,
    isFallback: false,
  });

  useEffect(() => {
    let cancelled = false;
    setState({ data: null, loading: true, error: null, isFallback: false });

    fetcher()
      .then((data) => {
        if (!cancelled) setState({ data, loading: false, error: null, isFallback: false });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        const message = err instanceof ApiError ? err.message : "Unknown error";
        try {
          const data = fallback();
          setState({ data, loading: false, error: message, isFallback: true });
        } catch {
          setState({ data: null, loading: false, error: message, isFallback: false });
        }
      });

    return () => {
      cancelled = true;
    };
    // deps is intentionally caller-supplied (generic hook) — the linter can't
    // statically verify it, but callers pass their own real dependency arrays.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
