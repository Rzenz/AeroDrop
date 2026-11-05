import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from 'react'

// ── A tiny shared store primitive ──────────────────────────────────────────
// ponytail: no query library. Every mutation bumps one global version and
// every mounted query refetches; at this data size that is cheaper than
// keeping a cache coherent. Swap for TanStack Query if pages start lagging.

type Listener = () => void

export function createStore<T>(initial: T) {
  let state = initial
  const listeners = new Set<Listener>()
  return {
    get: () => state,
    set(next: T | ((prev: T) => T)) {
      state = typeof next === 'function' ? (next as (p: T) => T)(state) : next
      listeners.forEach((l) => l())
    },
    subscribe(l: Listener) {
      listeners.add(l)
      return () => listeners.delete(l)
    },
  }
}

export function useStore<T>(store: ReturnType<typeof createStore<T>>) {
  return useSyncExternalStore(store.subscribe, store.get, store.get)
}

const version = createStore(0)
/** Refetch every mounted query. Call after any write. */
export const invalidate = () => version.set((v) => v + 1)

/** Coalesce bursts (realtime events, simulator ticks) into one refetch. */
let pending: ReturnType<typeof setTimeout> | null = null
export function invalidateSoon(ms = 400) {
  if (pending) return
  pending = setTimeout(() => {
    pending = null
    invalidate()
  }, ms)
}

export interface Query<T> {
  data: T | undefined
  error: string | null
  loading: boolean
  reload: () => void
}

/**
 * Fetch on mount, on `deps` change, and after every `invalidate()`.
 * `pollMs` keeps live screens (tracking, radar) fresh.
 */
export function useQuery<T>(fn: () => Promise<T>, deps: unknown[] = [], pollMs?: number): Query<T> {
  const v = useStore(version)
  const [tick, setTick] = useState(0)
  const [state, setState] = useState<{ data: T | undefined; error: string | null; loading: boolean }>({
    data: undefined,
    error: null,
    loading: true,
  })
  const fnRef = useRef(fn)
  fnRef.current = fn

  useEffect(() => {
    let alive = true
    setState((s) => ({ ...s, loading: s.data === undefined }))
    fnRef
      .current()
      .then((data) => alive && setState({ data, error: null, loading: false }))
      .catch((e: unknown) => alive && setState((s) => ({ ...s, error: errorMessage(e), loading: false })))
    return () => {
      alive = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [v, tick, ...deps])

  useEffect(() => {
    if (!pollMs) return
    const id = setInterval(() => {
      if (document.visibilityState === 'visible') setTick((t) => t + 1)
    }, pollMs)
    return () => clearInterval(id)
  }, [pollMs])

  const reload = useCallback(() => setTick((t) => t + 1), [])
  return { ...state, reload }
}

export function errorMessage(e: unknown): string {
  if (e instanceof Error) return e.message
  if (e && typeof e === 'object' && 'message' in e) return String((e as { message: unknown }).message)
  return 'Something went wrong. Please try again.'
}

/** Wrap a write: tracks pending state and refetches queries afterwards. */
export function useMutation<A extends unknown[], R>(fn: (...args: A) => Promise<R>) {
  const [pending, setPending] = useState(false)
  const run = useCallback(
    async (...args: A): Promise<R> => {
      setPending(true)
      try {
        const r = await fn(...args)
        invalidate()
        return r
      } finally {
        setPending(false)
      }
    },
    [fn],
  )
  return { run, pending }
}

// ── Persisted per-viewer preferences ───────────────────────────────────────
export function readLocal<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw == null ? fallback : (JSON.parse(raw) as T)
  } catch {
    return fallback
  }
}

export function writeLocal(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    /* private mode: preference just won't persist */
  }
}
