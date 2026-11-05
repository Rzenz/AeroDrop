// Adapted from ForgeUI "Text Morph" (npx shadcn add @forgeui/text-morph).
// Changes: 4px blur, 30ms char stagger, pauses when the tab is hidden, a
// live region that announces the word politely, static under reduced motion.

import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useMemo, useState } from 'react'
import { cn } from '@/lib/utils'

export function TextMorph({ words, interval = 2600, className }: { words: string[]; interval?: number; className?: string }) {
  const [index, setIndex] = useState(0)
  const reduce = useReducedMotion()

  useEffect(() => {
    if (reduce || words.length < 2) return
    const timer = setInterval(() => {
      if (document.visibilityState === 'visible') setIndex((i) => (i + 1) % words.length)
    }, interval)
    return () => clearInterval(timer)
  }, [words, interval, reduce])

  const chars = useMemo(() => Array.from(words[index] ?? ''), [index, words])
  if (reduce) return <span className={className}>{words[0]}</span>

  return (
    <span className={cn('relative inline-flex', className)}>
      <span className="sr-only">{words[index]}</span>
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.span
          key={index}
          aria-hidden
          className="inline-flex"
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6, transition: { duration: 0.15, ease: 'easeIn' } }}
          transition={{ duration: 0.3, ease: 'easeOut' }}
        >
          {chars.map((char, i) => (
            <motion.span
              key={i}
              className="whitespace-pre"
              initial={{ opacity: 0, y: 6, filter: 'blur(4px)' }}
              animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
              transition={{ delay: i * 0.03, duration: 0.3, ease: 'easeOut' }}
            >
              {char}
            </motion.span>
          ))}
        </motion.span>
      </AnimatePresence>
    </span>
  )
}

export default TextMorph
