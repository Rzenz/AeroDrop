// Adapted from ForgeUI "Animated Tabs" (npx shadcn add @forgeui/animated-tabs).
// Changes: controlled value, optional counts, ARIA tablist roles, brand tokens,
// a per-instance layoutId so two tab bars on one page don't share a pill.

import { motion } from 'motion/react'
import { useId, useRef, type KeyboardEvent } from 'react'
import { cn } from '@/lib/utils'

export interface TabItem<T extends string> {
  value: T
  label: string
  count?: number
}

interface AnimatedTabsProps<T extends string> {
  tabs: TabItem<T>[]
  value: T
  onChange: (v: T) => void
  variant?: 'default' | 'underline'
  label: string
  className?: string
}

export function AnimatedTabs<T extends string>({ tabs, value, onChange, variant = 'default', label, className }: AnimatedTabsProps<T>) {
  const id = useId()
  const refs = useRef<(HTMLButtonElement | null)[]>([])

  // Arrow keys move between tabs (roving tabindex).
  const onKey = (e: KeyboardEvent, i: number) => {
    const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0
    if (!d) return
    e.preventDefault()
    const next = (i + d + tabs.length) % tabs.length
    refs.current[next]?.focus()
    onChange(tabs[next]!.value)
  }

  const underline = variant === 'underline'
  return (
    <div
      role="tablist"
      aria-label={label}
      className={cn(
        'relative flex max-w-full items-center overflow-x-auto [scrollbar-width:none]',
        underline ? 'gap-1 shadow-[inset_0_-1px_0_var(--line)]' : 'w-fit gap-0.5 rounded-full bg-sunken p-1 shadow-[inset_0_0_0_1px_var(--line)]',
        className,
      )}
    >
      {tabs.map((tab, i) => {
        const active = tab.value === value
        return (
          <button
            key={tab.value}
            ref={(el) => {
              refs.current[i] = el
            }}
            role="tab"
            type="button"
            aria-selected={active}
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(tab.value)}
            onKeyDown={(e) => onKey(e, i)}
            className={cn(
              'relative flex shrink-0 items-center gap-1.5 text-sm font-medium whitespace-nowrap transition-colors duration-150',
              underline ? 'h-10 px-3' : 'h-8 rounded-full px-3.5',
              active ? (underline ? 'text-brand-ink' : 'text-on-brand') : 'text-ink-2 hover:text-ink',
            )}
          >
            {active && (
              <motion.span
                layoutId={`${id}-pill`}
                // Animate only when the selection changes, not when the page
                // around the tabs shifts (e.g. a centred card growing).
                layoutDependency={value}
                aria-hidden
                className={cn('absolute bg-brand', underline ? 'inset-x-0 bottom-0 h-0.5' : 'inset-0 rounded-full')}
                initial={false}
                transition={{ type: 'spring', stiffness: 500, damping: 30 }}
              />
            )}
            <span className="relative">{tab.label}</span>
            {tab.count != null && tab.count > 0 ? (
              <span className={cn('relative rounded-full px-1.5 text-[11px] leading-4 font-bold tabular-nums', active && !underline ? 'bg-white/25' : 'bg-surface text-ink-2 shadow-sm')}>
                {tab.count}
              </span>
            ) : null}
          </button>
        )
      })}
    </div>
  )
}

export default AnimatedTabs
