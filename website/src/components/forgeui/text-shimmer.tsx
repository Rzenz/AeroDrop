// Adapted from ForgeUI "Text Shimmer" (npx shadcn add @forgeui/text-shimmer).
// Changes: brand ink tokens, static text under prefers-reduced-motion.

import { motion, useReducedMotion } from 'motion/react'
import { memo, useMemo, type CSSProperties, type ElementType } from 'react'
import { cn } from '@/lib/utils'

export type TextShimmerProps = {
  children: string
  as?: ElementType
  className?: string
  duration?: number
  spread?: number
}

function TextShimmer({ children, as: Component = 'p', className, duration = 2, spread = 2 }: TextShimmerProps) {
  const reduce = useReducedMotion()
  const MotionComponent = useMemo(() => motion.create(Component as 'p'), [Component])
  const dynamicSpread = useMemo(() => children.length * spread, [children, spread])

  if (reduce) return <Component className={cn('text-ink-2', className)}>{children}</Component>

  return (
    <MotionComponent
      className={cn(
        'relative inline-block bg-size-[250%_100%,auto] bg-clip-text text-transparent',
        '[--base-color:var(--ink-3)] [--base-gradient-color:var(--ink)]',
        '[background-repeat:no-repeat,padding-box] [--bg:linear-gradient(90deg,#0000_calc(50%-var(--spread)),var(--base-gradient-color),#0000_calc(50%+var(--spread)))]',
        className,
      )}
      initial={{ backgroundPosition: '105% center' }}
      animate={{ backgroundPosition: '-5% center' }}
      transition={{ repeat: Number.POSITIVE_INFINITY, duration, ease: 'linear' }}
      style={{ '--spread': `${dynamicSpread}px`, backgroundImage: 'var(--bg), linear-gradient(var(--base-color), var(--base-color))' } as CSSProperties}
    >
      {children}
    </MotionComponent>
  )
}

export default memo(TextShimmer)
