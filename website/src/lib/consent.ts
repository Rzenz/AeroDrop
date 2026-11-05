import { createStore, readLocal, useStore, writeLocal } from './store'

/**
 * Cookie and storage consent. AeroDrop sets no advertising or analytics
 * cookies; what it keeps in the browser falls into two groups:
 *
 * - Strictly necessary (always on): the Supabase sign-in session, the
 *   sign-in-code unlock, the cart, and this choice itself.
 * - Preferences (opt-in): the light/dark theme and the admin console settings.
 */
export interface Consent {
  version: 1
  preferences: boolean
  decidedAt: string
}

const KEY = 'aerodrop-consent'
/** Storage that only exists with the Preferences category. */
const PREFERENCE_KEYS = ['aerodrop-theme', 'aerodrop-admin-prefs']

function load(): Consent | null {
  const c = readLocal<Consent | null>(KEY, null)
  return c && c.version === 1 && typeof c.preferences === 'boolean' ? c : null
}

const consentStore = createStore<Consent | null>(load())
const settingsOpen = createStore(false)

export const useConsent = () => useStore(consentStore)
export const useCookieSettingsOpen = () => useStore(settingsOpen)

/** Whether preference storage (theme, console settings) may be written. */
export const canStorePreferences = () => consentStore.get()?.preferences === true

export function saveConsent(preferences: boolean) {
  const c: Consent = { version: 1, preferences, decidedAt: new Date().toISOString() }
  writeLocal(KEY, c)
  if (!preferences) {
    for (const k of PREFERENCE_KEYS) {
      try {
        localStorage.removeItem(k)
      } catch {
        /* storage blocked: nothing was stored either */
      }
    }
  } else {
    // Keep the theme already on screen now that it may be remembered.
    try {
      const t = document.documentElement.dataset.theme
      if (t === 'light' || t === 'dark') localStorage.setItem('aerodrop-theme', t)
    } catch {
      /* ignore */
    }
  }
  consentStore.set(c)
  settingsOpen.set(false)
}

export const openCookieSettings = () => settingsOpen.set(true)
export const closeCookieSettings = () => settingsOpen.set(false)
