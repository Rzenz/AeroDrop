import { CloudRain, CloudSun, Eye, Thermometer, Wind } from 'lucide-react'
import { api } from '@/data/api'
import { timeAgo } from '@/lib/format'
import { useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { WeatherState } from '@/types'
import { Skeleton } from './ui/loader'
import { Card } from './ui/primitives'

export const weatherMeta: Record<WeatherState, { label: string; cls: string; note: string }> = {
  safe: { label: 'SAFE', cls: 'bg-success-bg text-success', note: 'Drones are flying normally.' },
  caution: { label: 'CAUTION', cls: 'bg-warning-bg text-warning', note: 'Slower flights and a ₱5 surcharge.' },
  grounded: { label: 'GROUNDED', cls: 'bg-danger-bg text-danger', note: 'New orders are paused until conditions improve.' },
}

/** "UCLM Campus Weather", read-only for customers and vendors. */
export function WeatherCard({ className }: { className?: string }) {
  const q = useQuery(() => api.weather(), [], 60_000)
  if (!q.data) return <Skeleton className={cn('h-40 rounded-2xl', className)} />
  const w = q.data
  const meta = weatherMeta[w.safety_status] ?? weatherMeta.safe
  return (
    <Card className={cn('@container p-5', className)}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm text-ink-2">UCLM Campus Weather</p>
          <p className="mt-1 font-display text-2xl font-bold text-ink">{w.condition ?? 'No reading yet'}</p>
        </div>
        <span className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-bold', meta.cls)}>
          <CloudSun aria-hidden className="size-3.5" />
          {meta.label}
        </span>
      </div>
      <p className="mt-1 text-sm text-ink-3">{w.message ?? meta.note}</p>
      <dl className="mt-4 grid grid-cols-2 gap-2 @md:grid-cols-4">
        {[
          { icon: Thermometer, k: 'Temperature', v: w.temperature != null ? `${Number(w.temperature).toFixed(1)}°C` : '—' },
          { icon: Wind, k: 'Wind & Gusts', v: w.wind_speed != null ? `${Math.round(w.wind_speed)} / ${Math.round(w.wind_gusts ?? w.wind_speed)} km/h` : '—' },
          { icon: CloudRain, k: 'Rain', v: w.precipitation != null ? `${Number(w.precipitation).toFixed(1)} mm/h` : '—' },
          { icon: Eye, k: 'Visibility', v: w.visibility != null ? `${(Number(w.visibility) / 1000).toFixed(0)} km` : '—' },
        ].map((x) => (
          <div key={x.k} className="rounded-xl bg-sunken px-3 py-2">
            <dt className="flex items-center gap-1 text-[11px] text-ink-3">
              <x.icon aria-hidden className="size-3" />
              {x.k}
            </dt>
            <dd className="mt-0.5 text-sm font-semibold text-ink tabular-nums">{x.v}</dd>
          </div>
        ))}
      </dl>
      <p className="mt-3 text-[11px] text-ink-3">Updated {timeAgo(w.updated_at)}{w.override_status ? ' · manual override by admin' : ''}</p>
    </Card>
  )
}
