// Adapted from ForgeUI "Text Reveal" (npx shadcn add @forgeui/text-reveal).
// Changes: 4px blur and 40ms word stagger (better-ui / 12-principles caps),
// screen readers get the sentence once, static under reduced motion.

import { motion, stagger, useAnimate, useReducedMotion } from 'motion/react'
import { useEffect } from 'react'
import { cn } from '@/lib/utils'

export default function TextReveal({ text, className, delay = 0 }: { text: string; className?: string; delay?: number }) {
  const [scope, animate] = useAnimate()
  const reduce = useReducedMotion()
  const words = text.split(' ')

  useEffect(() => {
    if (reduce) return
    animate('span', { opacity: 1, filter: 'blur(0px)', y: 0 }, { duration: 0.4, delay: stagger(0.04, { startDelay: delay }), ease: 'easeOut' })
  }, [animate, delay, reduce])

  if (reduce) return <p className={className}>{text}</p>

  return (
    <p className={cn('leading-normal', className)} aria-label={text}>
      <span ref={scope} aria-hidden>
        {words.map((word, i) => (
          <motion.span key={word + i} className="mr-[0.25em] inline-block" style={{ opacity: 0, filter: 'blur(4px)', y: 6 }}>
            {word}
          </motion.span>
        ))}
      </span>
    </p>
  )
}
