import { motion, useReducedMotion, type Variants } from 'motion/react'
import { Link } from 'react-router-dom'
import { PhoneCarousel } from '@/components/app-shot'
import { PlayStoreButton, RippleLink } from '@/components/brand'
import { TextMorph } from '@/components/forgeui/text-morph'
import TextReveal from '@/components/forgeui/text-reveal'
import { SiteHeader } from '@/components/site-header'

const rise: Variants = {
  hidden: { opacity: 0, y: 12, filter: 'blur(4px)' },
  show: { opacity: 1, y: 0, filter: 'blur(0px)', transition: { duration: 0.45, ease: [0.16, 1, 0.3, 1] } },
}

export default function Landing() {
  const reduce = useReducedMotion()

  return (
    <div className="flex min-h-dvh flex-col overflow-x-clip bg-bg text-ink">
      <SiteHeader />

      <main className="mx-auto grid w-full max-w-6xl flex-1 items-center gap-12 px-4 py-10 sm:px-6 lg:grid-cols-[1.15fr_0.85fr] lg:py-8">
        <motion.div initial={reduce ? false : 'hidden'} animate="show" variants={{ show: { transition: { staggerChildren: 0.1 } } }}>
          <motion.h1 variants={rise} className="font-display text-4xl leading-[1.08] font-extrabold text-ink sm:text-5xl lg:text-6xl">
            Your <TextMorph words={['iced latte', 'rice meal', 'milk tea', 'yellow pad']} className="text-brand" />
            <br />
            flown to your building.
          </motion.h1>
          <TextReveal
            delay={0.25}
            className="mt-5 max-w-xl text-lg text-ink-2"
            text="AeroDrop delivers meals, books and campus supplies by drone. Order from a campus vendor, watch the flight live, and pick it up at your drop-off building."
          />
          <motion.div variants={rise} className="mt-8 flex flex-wrap items-center gap-3">
            <PlayStoreButton size="lg" />
            <RippleLink to="/sign-up">Sign up free</RippleLink>
          </motion.div>
          <motion.p variants={rise} className="mt-4 text-sm text-ink-3">
            Already have an account?{' '}
            <Link to="/sign-in" className="font-semibold text-brand-ink underline-offset-2 hover:underline">
              Sign in on the web
            </Link>
          </motion.p>
        </motion.div>

        <motion.div
          initial={reduce ? false : { opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0, transition: { duration: 0.5, delay: 0.15, ease: [0.16, 1, 0.3, 1] } }}
          className="mx-auto w-full max-w-[300px] lg:mr-0"
        >
          {/* Real screens of the Flutter app (see tools/app-shots). Home is left
              out: in light theme the app's in-transit card draws its title in white. */}
          <PhoneCarousel
            screens={[
              { name: 'track', label: 'Live tracking', darkStatus: true, alt: 'AeroDrop app live tracking: flight over the UCLM campus map, battery 86%, speed 6.2 m/s' },
              { name: 'chat', label: 'Order chat', alt: 'AeroDrop app order chat between Maria and Kape Kanto about less ice and the drop-off lobby' },
              { name: 'shop', label: 'Shop', alt: 'AeroDrop app shop listing four open campus stores with ratings' },
            ]}
          />
        </motion.div>
      </main>
    </div>
  )
}
