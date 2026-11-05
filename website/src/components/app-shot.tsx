import { AnimatePresence, motion, useInView, useReducedMotion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { useTheme } from '@/lib/theme'
import { cn } from '@/lib/utils'

// Every image here is a real screen of the AeroDrop Flutter app, rendered by
// the app itself against demo data and exported to public/app/ in a light and
// a dark version. The site shows whichever matches its own theme.

export type ShotName = 'track' | 'chat' | 'shop' | 'vendor' | 'admin'

/** Every export is a full 390 × 844 pt screen at 2x. */
const SIZE: [number, number] = [780, 1688]

/** The app's own canvas colours (AppColors.bgLight / bgDark), so crops sit flush. */
export const APP_CANVAS = { light: '#EBF1FB', dark: '#19223B' }

export function AppShot({ name, alt, className, eager, theme: forced }: { name: ShotName; alt: string; className?: string; eager?: boolean; theme?: 'light' | 'dark' }) {
  const siteTheme = useTheme()
  const theme = forced ?? siteTheme
  const [w, h] = SIZE
  return (
    <img
      src={`/app/${name}-${theme}.webp`}
      alt={alt}
      width={w}
      height={h}
      loading={eager ? 'eager' : 'lazy'}
      decoding="async"
      className={cn('no-outline block h-auto w-full select-none', className)}
      draggable={false}
    />
  )
}

/**
 * iPhone-proportioned frame (390 × 844 pt). The screens were rendered with
 * the device's safe areas, so the status bar and home indicator drawn here
 * sit in space the app itself left empty.
 */
export function PhoneFrame({ children, className, darkStatus }: { children: React.ReactNode; className?: string; darkStatus?: boolean }) {
  const theme = useTheme()
  const ink = (darkStatus ?? theme === 'dark') ? '#ffffff' : '#16203A'
  return (
    <div className={cn('relative rounded-[3.25rem] bg-black p-[0.6rem] shadow-lg ring-1 ring-black/10 dark:ring-white/15', className)}>
      <div className="@container relative aspect-[390/844] overflow-hidden rounded-[2.7rem]" style={{ background: APP_CANVAS[theme] }}>
        {children}
        <div aria-hidden className="pointer-events-none absolute inset-x-0 top-0 flex h-[5.6%] items-center justify-between px-[8%] pt-[1%]">
          <span className="font-sans text-[clamp(10px,3.6cqw,15px)] font-semibold tabular-nums" style={{ color: ink }}>
            11:42
          </span>
          <span className="flex items-center gap-1" style={{ color: ink }}>
            <svg viewBox="0 0 18 12" className="h-[0.7em] w-auto text-[clamp(10px,3.6cqw,15px)]" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
            <svg viewBox="0 0 16 12" className="h-[0.7em] w-auto text-[clamp(10px,3.6cqw,15px)]" fill="currentColor"><path d="M8 2.2c2.3 0 4.4.9 6 2.4l1.3-1.4A10.4 10.4 0 0 0 8 .3 10.4 10.4 0 0 0 .7 3.2L2 4.6a8.5 8.5 0 0 1 6-2.4Zm0 3.8c1.3 0 2.5.5 3.4 1.3l1.3-1.4A6.8 6.8 0 0 0 8 4.1a6.8 6.8 0 0 0-4.7 1.8l1.3 1.4A4.9 4.9 0 0 1 8 6Zm0 3.7 1.9-2a2.9 2.9 0 0 0-3.8 0Z" /></svg>
            <svg viewBox="0 0 27 13" className="h-[0.75em] w-auto text-[clamp(10px,3.6cqw,15px)]" fill="none"><rect x=".5" y=".5" width="23" height="12" rx="3.5" stroke="currentColor" opacity=".4" /><rect x="2" y="2" width="17" height="9" rx="2" fill="currentColor" /><path d="M25 4.5v4c.8-.3 1.5-1.1 1.5-2s-.7-1.7-1.5-2Z" fill="currentColor" opacity=".45" /></svg>
          </span>
        </div>
        <div aria-hidden className="pointer-events-none absolute top-[1.3%] left-1/2 h-[4.1%] w-[31%] -translate-x-1/2 rounded-full bg-black" />
        <div aria-hidden className="pointer-events-none absolute bottom-[1%] left-1/2 h-[0.6%] w-[35%] -translate-x-1/2 rounded-full" style={{ background: ink, opacity: 0.85 }} />
      </div>
    </div>
  )
}

export interface PhoneScreen {
  name: ShotName
  label: string
  alt: string
  /** Status bar ink: the tracking map is dark in both themes. */
  darkStatus?: boolean
}

/**
 * Real screens in a phone, cross-fading every few seconds. Stops while off
 * screen or hidden, and never auto-advances for reduced-motion users.
 */
export function PhoneCarousel({ screens, interval = 4200, className }: { screens: PhoneScreen[]; interval?: number; className?: string }) {
  const [i, setI] = useState(0)
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { amount: 0.3 })
  const reduce = useReducedMotion()
  const [paused, setPaused] = useState(false)

  useEffect(() => {
    if (!inView || reduce || paused) return
    const id = setInterval(() => document.visibilityState === 'visible' && setI((n) => (n + 1) % screens.length), interval)
    return () => clearInterval(id)
  }, [inView, reduce, paused, interval, screens.length])

  const s = screens[i]!
  return (
    <div ref={ref} className={cn('flex flex-col items-center gap-5', className)} onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)}>
      <PhoneFrame className="w-full" darkStatus={s.darkStatus}>
        <AnimatePresence initial={false}>
          <motion.div
            key={s.name}
            className="absolute inset-0"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1, transition: { duration: 0.35, ease: 'easeOut' } }}
            exit={{ opacity: 0, transition: { duration: 0.25, ease: 'easeIn' } }}
          >
            <AppShot name={s.name} alt={s.alt} eager={i === 0} />
          </motion.div>
        </AnimatePresence>
      </PhoneFrame>
      <div role="tablist" aria-label="App screens" className="flex flex-wrap justify-center gap-1.5">
        {screens.map((sc, n) => (
          <button
            key={sc.name}
            role="tab"
            type="button"
            aria-selected={n === i}
            onClick={() => setI(n)}
            className={cn(
              'h-9 rounded-full px-3.5 text-xs font-semibold transition-[background-color,color,transform] duration-150 ease-out active:scale-[0.96]',
              n === i ? 'bg-brand text-on-brand' : 'bg-surface text-ink-2 shadow-sm hover:text-ink',
            )}
          >
            {sc.label}
          </button>
        ))}
      </div>
    </div>
  )
}
