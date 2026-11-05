// Adapted from ForgeUI "Stats Card" (npx shadcn add @forgeui/stats-card).
// Changes: no next/image or react-icons; avatars fall back to initials; hover
// OR keyboard focus flips to the runner-up; tokens for both themes.

import { TrendingDown, TrendingUp } from 'lucide-react'
import { Avatar } from '@/components/ui/primitives'
import { cn } from '@/lib/utils'

interface Person {
  name: string
  value: string
  image?: string | null
}

export default function StatsCard({
  title,
  description,
  metric,
  first,
  second,
  className,
}: {
  title: string
  description: string
  metric: string
  first: Person
  second?: Person
  className?: string
}) {
  return (
    <div
      tabIndex={0}
      aria-label={`${title}: ${first.name}, ${first.value} ${metric}${second ? `. Runner-up ${second.name}, ${second.value}` : ''}`}
      className={cn('group w-full rounded-2xl bg-surface p-5 shadow-md focus-visible:outline-2', className)}
    >
      <style>{`
        .sc-graph { offset-anchor: 10px 0px; animation: sc-path 3s cubic-bezier(0.2,0.6,0.6,0.3) infinite; offset-path: path("${PATH}"); }
        @keyframes sc-path { from { offset-distance: 0% } to { offset-distance: 100% } }
        @media (prefers-reduced-motion: reduce) { .sc-graph { animation: none; } }
      `}</style>
      <div aria-hidden className="relative h-64 overflow-hidden rounded-xl mask-[radial-gradient(50%_90%_at_50%_50%,white_30%,transparent_100%)]">
        <Face person={first} metric={metric} up className="transition-transform duration-200 ease-out group-hover:-translate-y-64 group-focus-visible:-translate-y-64" />
        {second ? (
          <Face person={second} metric={metric} className="translate-y-64 transition-transform duration-200 ease-out group-hover:translate-y-0 group-focus-visible:translate-y-0" />
        ) : null}
      </div>
      <h3 className="pt-2 text-base font-semibold text-ink">{title}</h3>
      <p className="mt-0.5 text-xs text-ink-3">{description}</p>
    </div>
  )
}

function Face({ person, metric, up, className }: { person: Person; metric: string; up?: boolean; className?: string }) {
  const Icon = up ? TrendingUp : TrendingDown
  return (
    <div className={cn('absolute inset-0 flex flex-col items-center justify-center', className)}>
      <div className="grid size-18 place-items-center rounded-2xl bg-surface-2 shadow-[inset_0_0_12px_rgba(0,0,0,0.12)]">
        <Avatar name={person.name} src={person.image} size={56} className="rounded-xl" />
      </div>
      <p className="mt-3 text-sm font-bold text-ink">{person.name}</p>
      <div className="mt-2 flex items-center gap-2 rounded-full bg-sunken px-3 py-1 text-xs">
        <Icon className={cn('size-3', up ? 'text-success' : 'text-danger')} />
        <span className="text-ink-3">{metric}</span>
        <span className="size-1 rounded-full bg-ink-3" />
        <span className="font-semibold text-ink tabular-nums">{person.value}</span>
      </div>
      <svg width="336" height="96" viewBox="0 0 336 126" fill="none" className="mt-3 max-w-full">
        <path d={PATH} stroke="currentColor" strokeWidth="1" className="text-ink-3/50" />
        <g mask={`url(#sc-mask-${up ? 1 : 2})`}>
          <circle className="sc-graph" cx="0" cy="0" r="20" fill={`url(#sc-grad-${up ? 1 : 2})`} />
        </g>
        <defs>
          <mask id={`sc-mask-${up ? 1 : 2}`}>
            <path d={PATH} strokeWidth="2" stroke="white" />
          </mask>
          <radialGradient id={`sc-grad-${up ? 1 : 2}`} fx="1">
            <stop offset="0%" stopColor="#4FB1F6" />
            <stop offset="20%" stopColor="#4FB1F6" stopOpacity="0.8" />
            <stop offset="100%" stopColor="transparent" />
          </radialGradient>
        </defs>
      </svg>
    </div>
  )
}

const PATH =
  'M0 1C10 1 10 58 20 66C30 74 30 112 40 110C50 108 50 125 60 122C70 119 70 52 80 52C90 52 90 95 100 90C110 85 110 65 120 70C130 75 130 83 140 82C150 81 150 60 160 64C170 68 170 58 180 58C190 58 190 50 200 54C210 58 210 92 220 90C230 88 230 98 240 94C250 90 250 114 260 112C270 110 270 96 280 100C290 104 290 40 300 40C310 40 310 102 320 104C330 106 330 106 336 104'
