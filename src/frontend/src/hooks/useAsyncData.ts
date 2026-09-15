import { useCallback, useEffect, useRef, useState } from "react";
import { ApiError } from "../api/client";

export interface AsyncResult<T> {
  data: T | null;
  /** True only while there is no data on screen yet (first load / dep change). */
  loading: boolean;
  /** True while a background refresh (manual or polled) is in flight; `data` still holds the last good value. */
  isRefreshing: boolean;
  error: string | null;
  isFallback: boolean;
  /** Wall-clock time of the last successful (real or fallback) fetch. */
  lastUpdatedAt: number | null;
  /** Re-run the fetch immediately without clearing currently displayed data. */
  refetch: () => void;
}

export interface UseAsyncDataOptions {
  /** When set, re-fetches on this interval (ms) in the background. */
  pollIntervalMs?: number;
}

/**
 * Fetches data from the real API. If the request fails (backend not running,
 * network error, non-2xx response), falls back to local mock data so the UI
 * stays demo-able. `isFallback` is surfaced so pages can show an unmissable
 * "demo data" banner instead of silently pretending it's live.
 *
 * Also supports lightweight polling and a manual `refetch`, both of which
 * refresh in the background (`isRefreshing`) rather than re-showing a loading
 * skeleton, so the page keeps its "live" feel instead of flashing empty. A
 * genuine change to `deps` (e.g. navigating to a different asset id) still
 * shows the initial-load skeleton, since the previously displayed data no
 * longer applies to the new resource.
 */
export function useAsyncData<T>(
  fetcher: () => Promise<T>,
  fallback: () => T,
  deps: unknown[],
  options: UseAsyncDataOptions = {},
): AsyncResult<T> {
  const { pollIntervalMs } = options;

  const [state, setState] = useState<AsyncResult<T>>({
    data: null,
    loading: true,
    isRefreshing: false,
    error: null,
    isFallback: false,
    lastUpdatedAt: null,
    refetch: () => {},
  });

  const [reloadToken, setReloadToken] = useState(0);
  const hasDataRef = useRef(false);
  const prevDepsKeyRef = useRef<string | null>(null);

  const refetch = useCallback(() => setReloadToken((t) => t + 1), []);

  useEffect(() => {
    let cancelled = false;

    const depsKey = JSON.stringify(deps);
    const depsChanged = prevDepsKeyRef.current !== depsKey;
    prevDepsKeyRef.current = depsKey;
    if (depsChanged) hasDataRef.current = false;
    const isInitialLoad = !hasDataRef.current;

    setState((prev) => ({
      ...prev,
      data: depsChanged ? null : prev.data,
      loading: isInitialLoad,
      isRefreshing: !isInitialLoad,
      error: null,
    }));

    fetcher()
      .then((data) => {
        if (cancelled) return;
        hasDataRef.current = true;
        setState({
          data,
          loading: false,
          isRefreshing: false,
          error: null,
          isFallback: false,
          lastUpdatedAt: Date.now(),
          refetch,
        });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        const message = err instanceof ApiError ? err.message : "Unknown error";
        try {
          const data = fallback();
          hasDataRef.current = true;
          setState({
            data,
            loading: false,
            isRefreshing: false,
            error: message,
            isFallback: true,
            lastUpdatedAt: Date.now(),
            refetch,
          });
        } catch {
          setState({
            data: null,
            loading: false,
            isRefreshing: false,
            error: message,
            isFallback: false,
            lastUpdatedAt: null,
            refetch,
          });
        }
      });

    return () => {
      cancelled = true;
    };
    // deps is intentionally caller-supplied (generic hook) — the linter can't
    // statically verify it, but callers pass their own real dependency arrays.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, reloadToken]);

  useEffect(() => {
    if (!pollIntervalMs) return;
    const id = setInterval(() => setReloadToken((t) => t + 1), pollIntervalMs);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pollIntervalMs, ...deps]);

  return state;
}
