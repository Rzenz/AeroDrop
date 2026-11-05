import { Cookie, Settings2 } from 'lucide-react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { closeCookieSettings, openCookieSettings, saveConsent, useConsent, useCookieSettingsOpen } from '@/lib/consent'
import { Button } from './ui/button'
import { Dialog } from './ui/dialog'
import { Badge, Switch } from './ui/primitives'

/**
 * Cookie consent: a toast-style card on first visit, and a settings dialog
 * that can be reopened later (Privacy Policy page, profile). Accept and
 * Reject carry equal weight so declining is as easy as agreeing.
 */
export function CookieConsent() {
  const consent = useConsent()
  const settingsOpen = useCookieSettingsOpen()
  const reduce = useReducedMotion()

  return (
    <>
      <AnimatePresence>
        {!consent && !settingsOpen ? (
          <motion.section
            key="cookie-consent"
            aria-labelledby="cookie-title"
            aria-describedby="cookie-body"
            initial={{ opacity: 0, y: reduce ? 0 : 16 }}
            animate={{ opacity: 1, y: 0, transition: { duration: 0.2, ease: [0.2, 0, 0, 1], delay: 0.4 } }}
            exit={{ opacity: 0, y: reduce ? 0 : 8, transition: { duration: 0.15, ease: 'easeOut' } }}
            className="fixed inset-x-4 bottom-[max(1rem,env(safe-area-inset-bottom))] z-40 rounded-2xl bg-surface p-5 shadow-lg sm:right-auto sm:left-6 sm:w-[26rem]"
          >
            <div className="flex gap-3.5">
              <span aria-hidden className="grid size-10 shrink-0 place-items-center rounded-xl bg-brand/12 text-brand-ink">
                <Cookie className="size-5" />
              </span>
              <div className="min-w-0">
                <h2 id="cookie-title" className="font-display font-bold text-ink">
                  Cookies on AeroDrop
                </h2>
                <p id="cookie-body" className="mt-1 text-sm text-pretty text-ink-2">
                  We use essential cookies and browser storage to keep you signed in and hold your cart. With your OK, we also remember preferences like your theme. No ads or tracking.{' '}
                  <Link to="/privacy" className="font-semibold text-brand-ink underline-offset-2 hover:underline">
                    Privacy Policy
                  </Link>
                </p>
              </div>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <Button variant="secondary" onClick={() => saveConsent(false)}>
                Reject All
              </Button>
              <Button onClick={() => saveConsent(true)}>Accept All Cookies</Button>
            </div>
            <button
              type="button"
              onClick={openCookieSettings}
              className="mx-auto mt-2 flex h-10 items-center gap-1.5 rounded-lg px-3 text-sm font-semibold text-ink-2 transition-[color,background-color,scale] duration-150 hover:bg-sunken hover:text-ink active:scale-[0.96]"
            >
              <Settings2 aria-hidden className="size-4" />
              Cookie Settings
            </button>
          </motion.section>
        ) : null}
      </AnimatePresence>
      {settingsOpen ? <CookieSettings preferences={consent?.preferences ?? false} /> : null}
    </>
  )
}

function CookieSettings({ preferences: initial }: { preferences: boolean }) {
  const [preferences, setPreferences] = useState(initial)

  return (
    <Dialog open onOpenChange={(v) => !v && closeCookieSettings()} title="Cookie Settings" description="Choose what AeroDrop may keep in this browser. You can change this any time from the Privacy Policy page.">
      <ul className="divide-y divide-line rounded-xl bg-sunken px-4">
        <li className="flex items-start justify-between gap-4 py-4">
          <div>
            <p className="flex items-center gap-2 font-medium text-ink">
              Strictly necessary <Badge>Always on</Badge>
            </p>
            <p className="mt-1 text-sm text-ink-2">Keep you signed in, confirm your sign-in code, hold your cart and remember this choice. The site can’t work without them.</p>
          </div>
          <Switch label="Strictly necessary cookies (always on)" checked disabled onChange={() => undefined} />
        </li>
        <li className="flex items-start justify-between gap-4 py-4">
          <div>
            <p className="font-medium text-ink">Preferences</p>
            <p className="mt-1 text-sm text-ink-2">Remember your light or dark theme and admin console settings on this device. Without them, the theme follows your system each visit.</p>
          </div>
          <Switch label="Preference cookies" checked={preferences} onChange={setPreferences} />
        </li>
      </ul>
      <p className="mt-3 text-xs text-ink-3">AeroDrop doesn’t use analytics or advertising cookies.</p>
      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button variant="ghost" onClick={() => saveConsent(false)}>
          Reject All
        </Button>
        <Button variant="secondary" onClick={() => saveConsent(preferences)}>
          Save Choices
        </Button>
        <Button onClick={() => saveConsent(true)}>Accept All Cookies</Button>
      </div>
    </Dialog>
  )
}
