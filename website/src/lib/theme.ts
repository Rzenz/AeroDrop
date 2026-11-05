import { createStore, useStore } from './store'

export type Theme = 'light' | 'dark'
const KEY = 'aerodrop-theme'

const themeStore = createStore<Theme>((document.documentElement.dataset.theme as Theme) || 'light')

// Keep the browser chrome (mobile address bar) the same pure white or black
// as the page, whoever flips data-theme: the toggle or the admin console.
const meta = document.querySelector<HTMLMetaElement>('meta[name=theme-color]')
new MutationObserver(() => {
  if (meta) meta.content = document.documentElement.dataset.theme === 'dark' ? '#000000' : '#ffffff'
}).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })
export const useTheme = () => useStore(themeStore)

export function setTheme(t: Theme) {
  // Suppress transitions for the swap so the whole page snaps instead of
  // smearing every colour transition at once (better-ui).
  const style = document.createElement('style')
  style.textContent = '*,*::before,*::after{transition:none!important}'
  document.head.appendChild(style)
  document.documentElement.dataset.theme = t
  void document.body.offsetHeight
  requestAnimationFrame(() => style.remove())
  // Stored as a bare string: the boot script in index.html reads it pre-paint.
  try {
    localStorage.setItem(KEY, t)
  } catch {
    /* ignore */
  }
  themeStore.set(t)
}
