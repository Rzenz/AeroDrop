import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { cn } from '@/lib/utils'

// Chart chrome follows the dataviz skill: one series = one colour (the brand
// blue), hairline solid grid, muted axis ink, 4px rounded data ends, a hover
// tooltip on every bar, and a visually hidden table for screen readers.

export interface Datum {
  label: string
  value: number
}

export function BarSeries({ data, format = (v) => String(v), height = 240, name }: { data: Datum[]; format?: (v: number) => string; height?: number; name: string }) {
  return (
    <figure>
      <div style={{ height }} aria-hidden>
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -12 }} barCategoryGap="28%">
            <CartesianGrid vertical={false} stroke="var(--line)" strokeWidth={1} />
            <XAxis dataKey="label" tickLine={false} axisLine={{ stroke: 'var(--line)' }} tick={{ fill: 'var(--ink-3)', fontSize: 11 }} interval="preserveStartEnd" minTickGap={8} />
            <YAxis tickLine={false} axisLine={false} tick={{ fill: 'var(--ink-3)', fontSize: 11 }} tickFormatter={format} width={56} allowDecimals={false} />
            <Tooltip
              cursor={{ fill: 'var(--sunken)' }}
              content={({ active, payload, label }) =>
                active && payload?.length ? (
                  <div className="rounded-lg bg-surface px-3 py-2 text-xs shadow-lg">
                    <p className="text-ink-3">{label}</p>
                    <p className="mt-0.5 font-semibold text-ink tabular-nums">
                      {name}: {format(Number(payload[0]!.value))}
                    </p>
                  </div>
                ) : null
              }
            />
            <Bar dataKey="value" name={name} fill="var(--brand)" radius={[4, 4, 0, 0]} maxBarSize={36} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>
      <table className="sr-only">
        <caption>{name}</caption>
        <tbody>
          {data.map((d) => (
            <tr key={d.label}>
              <th scope="row">{d.label}</th>
              <td>{format(d.value)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}

export interface Segment {
  label: string
  value: number
  color: string
}

/** Part-to-whole as one segmented bar with a labelled legend (≤ 6 parts). */
export function SegmentedBar({ segments, className }: { segments: Segment[]; className?: string }) {
  const total = segments.reduce((s, x) => s + x.value, 0) || 1
  return (
    <div className={className}>
      <div className="flex h-3 gap-[2px] overflow-hidden rounded-full" role="img" aria-label={segments.map((s) => `${s.label} ${s.value}`).join(', ')}>
        {segments
          .filter((s) => s.value > 0)
          .map((s) => (
            <div key={s.label} title={`${s.label}: ${s.value}`} className="h-full first:rounded-l-full last:rounded-r-full" style={{ flexGrow: s.value, background: s.color }} />
          ))}
      </div>
      <ul className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
        {segments.map((s) => (
          <li key={s.label} className="flex items-center gap-2">
            <span aria-hidden className="size-2.5 shrink-0 rounded-sm" style={{ background: s.color }} />
            <span className="flex-1 text-ink-2">{s.label}</span>
            <span className="font-semibold text-ink tabular-nums">{s.value}</span>
            <span className="w-10 text-right text-xs text-ink-3 tabular-nums">{Math.round((s.value / total) * 100)}%</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

/** Status palette from the dataviz reference; always shown with a label. */
export const STATUS_COLORS = { good: '#0ca30c', warning: '#fab219', critical: '#d03b3b', info: 'var(--brand)', neutral: 'var(--ink-3)' }

export function Meter({ value, className, tone = 'info', label }: { value: number; className?: string; tone?: keyof typeof STATUS_COLORS; label: string }) {
  const pct = Math.round(Math.max(0, Math.min(100, value)))
  return (
    <div role="meter" aria-label={label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} className={cn('h-1.5 overflow-hidden rounded-full bg-sunken', className)}>
      <div className="h-full origin-left rounded-full" style={{ transform: `scaleX(${pct / 100})`, background: STATUS_COLORS[tone] }} />
    </div>
  )
}

export function lastNDays(n: number) {
  const days: { key: string; label: string }[] = []
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date()
    d.setHours(0, 0, 0, 0)
    d.setDate(d.getDate() - i)
    days.push({ key: d.toDateString(), label: d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }) })
  }
  return days
}
