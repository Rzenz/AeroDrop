import { motion, useReducedMotion } from 'motion/react'
import { Link } from 'react-router-dom'
import { PlayStoreButton } from '@/components/brand'
import { PLAY_STORE_URL } from '@/lib/config'
import { HoloCard } from '@/components/holo-card'
import { SiteHeader } from '@/components/site-header'
import { team } from '@/data/team'
import { usePageTitle } from '@/lib/use-page-title'

export default function Team() {
  usePageTitle('Meet the Team')
  const reduce = useReducedMotion()

  return (
    <div className="min-h-dvh overflow-x-clip bg-bg text-ink">
      <SiteHeader />
      <main className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6 sm:pt-20">
        <header className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-semibold text-brand-ink">Meet the Team</p>
          <h1 className="mt-3 font-display text-4xl font-extrabold text-ink sm:text-5xl">The students behind AeroDrop</h1>
          <p className="mt-5 text-lg text-ink-2">
            AeroDrop is a capstone project by Bachelor of Science in Information Technology students of the University of Cebu Lapu-Lapu and Mandaue.
          </p>
        </header>

        <motion.ul
          className="mt-14 grid gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-4"
          initial={reduce ? false : 'hidden'}
          animate="show"
          variants={{ show: { transition: { staggerChildren: 0.05 } } }}
        >
          {team.map((m, i) => (
            <motion.li key={`${m.name}-${i}`} variants={{ hidden: { opacity: 0, y: 12 }, show: { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] } } }}>
              <HoloCard name={m.name} role={m.role} photo={m.photo} />
            </motion.li>
          ))}
        </motion.ul>

        <div className="mt-20 flex flex-col items-center gap-4 text-center">
          <p className="text-ink-2">See what we built.</p>
          {PLAY_STORE_URL ? (
            <PlayStoreButton />
          ) : (
            <Link to="/sign-in" className="inline-flex h-12 items-center rounded-xl bg-brand px-5 font-semibold text-on-brand shadow-sm transition-[transform,filter] duration-150 hover:brightness-110 active:scale-[0.96]">
              Open AeroDrop
            </Link>
          )}
        </div>
      </main>
    </div>
  )
}
