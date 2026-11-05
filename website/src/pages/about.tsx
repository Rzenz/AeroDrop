import { ArrowRight, CheckCircle2, FlaskConical, ShieldCheck, Store, Users } from 'lucide-react'
import { motion, useReducedMotion, type Variants } from 'motion/react'
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { AppShot, PhoneFrame, type ShotName } from '@/components/app-shot'
import { PlayStoreButton } from '@/components/brand'
import { PLAY_STORE_URL } from '@/lib/config'
import { SiteHeader } from '@/components/site-header'
import { usePageTitle } from '@/lib/use-page-title'

// Facts here come from the project README, so the site and the docs agree.

const rise: Variants = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.45, ease: [0.16, 1, 0.3, 1] } },
}

function Reveal({ children, className, delay = 0 }: { children: ReactNode; className?: string; delay?: number }) {
  const reduce = useReducedMotion()
  return (
    <motion.div className={className} initial={reduce ? false : 'hidden'} whileInView="show" viewport={{ once: true, amount: 0.2 }} variants={rise} transition={{ delay }}>
      {children}
    </motion.div>
  )
}

const roles: { shot: ShotName; alt: string; icon: ReactNode; title: string; body: string }[] = [
  { shot: 'shop', alt: 'Customer Shop screen in the app', icon: <Users />, title: 'Customers', body: 'Students, faculty and staff browse campus stores, pay, message the vendor and track the drone on a live map.' },
  { shot: 'vendor', alt: 'Vendor home screen in the app', icon: <Store />, title: 'Vendors', body: 'Approved campus stores manage products and stock, then confirm, prepare and mark orders ready for the drone.' },
  { shot: 'admin', alt: 'Admin Command Deck in the app', icon: <ShieldCheck />, title: 'Administrators', body: 'Staff approve vendors and manage accounts, drones, deliveries, campus weather, support reports and analytics.' },
]

export default function About() {
  usePageTitle('About Us')
  return (
    <div className="min-h-dvh overflow-x-clip bg-bg text-ink">
      <SiteHeader />
      <main>
        <section className="mx-auto max-w-3xl px-4 pt-14 pb-16 text-center sm:px-6 sm:pt-20">
          <Reveal>
            <p className="text-sm font-semibold text-brand-ink">About Us</p>
            <h1 className="mt-3 font-display text-4xl font-extrabold text-ink sm:text-5xl">A campus marketplace that delivers by drone</h1>
            <p className="mt-5 text-lg text-ink-2">
              AeroDrop is a capstone project by Bachelor of Science in Information Technology students of the University of Cebu Lapu-Lapu and Mandaue. It connects people on
              campus with approved vendors and flies small orders to four drop-off buildings.
            </p>
          </Reveal>
        </section>

        <section aria-labelledby="roles" className="mx-auto max-w-6xl px-4 pb-20 sm:px-6">
          <h2 id="roles" className="sr-only">Who uses AeroDrop</h2>
          <div className="grid gap-4 md:grid-cols-3">
            {roles.map((r, i) => (
              <Reveal key={r.title} delay={i * 0.06} className="h-full">
                <article className="flex h-full flex-col overflow-hidden rounded-3xl bg-surface shadow-md">
                  <div className="relative h-64 overflow-hidden bg-sunken px-10 pt-7">
                    {/* The app paints admin screens dark in both themes. */}
                    <PhoneFrame className="mx-auto w-[210px]" darkStatus={r.shot === 'admin' ? true : undefined}>
                      <AppShot name={r.shot} alt={r.alt} />
                    </PhoneFrame>
                    <div aria-hidden className="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-surface to-transparent" />
                  </div>
                  <div className="p-6 pt-3">
                    <div className="flex items-center gap-3">
                      <span aria-hidden className="grid size-10 place-items-center rounded-xl bg-gradient-to-b from-[#4FB1F6] to-[#3A6FD4] text-white [&_svg]:size-5">{r.icon}</span>
                      <h3 className="text-lg font-bold text-ink">{r.title}</h3>
                    </div>
                    <p className="mt-3 text-sm text-ink-2">{r.body}</p>
                  </div>
                </article>
              </Reveal>
            ))}
          </div>
        </section>

        <section className="bg-surface-2 py-20">
          <div className="mx-auto grid max-w-6xl gap-10 px-4 sm:px-6 lg:grid-cols-2">
            <Reveal>
              <h2 className="font-display text-3xl font-extrabold text-ink">What’s real, and what’s simulated</h2>
              <p className="mt-3 text-ink-2">A prototype should say which parts are live. These are the ones in AeroDrop.</p>
            </Reveal>
            <div className="grid gap-4 sm:grid-cols-2">
              <Reveal className="rounded-2xl bg-surface p-5 shadow-sm">
                <h3 className="flex items-center gap-2 font-semibold text-ink">
                  <CheckCircle2 aria-hidden className="size-5 text-success" /> Real
                </h3>
                <ul className="mt-3 space-y-1.5 text-sm text-ink-2">
                  {['Campus weather from Open-Meteo', 'Campus coordinates and maps', 'Sign-in with emailed codes', 'Order chat and notifications', 'Online payments through Xendit', 'Reviews and every stored record'].map((x) => <li key={x}>{x}</li>)}
                </ul>
              </Reveal>
              <Reveal delay={0.06} className="rounded-2xl bg-surface p-5 shadow-sm">
                <h3 className="flex items-center gap-2 font-semibold text-ink">
                  <FlaskConical aria-hidden className="size-5 text-warning" /> Simulated
                </h3>
                <ul className="mt-3 space-y-1.5 text-sm text-ink-2">
                  {['Drone flight and telemetry', 'Simulated GCash and card payments', 'Refunds on cancelled orders'].map((x) => <li key={x}>{x}</li>)}
                </ul>
              </Reveal>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
          <Reveal>
            <h2 className="font-display text-3xl font-extrabold text-ink">Built with</h2>
          </Reveal>
          <ul className="mt-6 flex flex-wrap gap-2">
            {['Flutter', 'Dart', 'Riverpod', 'Supabase', 'PostgreSQL', 'Supabase Realtime', 'Edge Functions', 'Xendit', 'Open-Meteo', 'OpenStreetMap'].map((t) => (
              <li key={t} className="rounded-full bg-surface px-4 py-2 text-sm font-medium text-ink-2 shadow-sm">{t}</li>
            ))}
          </ul>
          <Reveal className="mt-14 flex flex-col items-start gap-5 rounded-3xl bg-surface p-8 shadow-md sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="font-display text-2xl font-bold text-ink">{PLAY_STORE_URL ? 'Try it on your phone' : 'Try it in your browser'}</h2>
              <p className="mt-1 text-ink-2">Or meet the students who built it.</p>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              {PLAY_STORE_URL ? (
                <PlayStoreButton />
              ) : (
                <Link to="/sign-in" className="inline-flex h-12 items-center rounded-xl bg-brand px-5 font-semibold text-on-brand shadow-sm transition-[transform,filter] duration-150 hover:brightness-110 active:scale-[0.96]">
                  Open AeroDrop
                </Link>
              )}
              <Link to="/team" className="inline-flex h-12 items-center gap-1.5 rounded-xl px-4 font-semibold text-brand-ink transition-colors duration-150 hover:bg-sunken">
                Meet the Team <ArrowRight aria-hidden className="size-4" />
              </Link>
            </div>
          </Reveal>
        </section>
      </main>
    </div>
  )
}
