import { CloudLightning, CloudSun, Play, Sun, Wind } from 'lucide-react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/ui/dialog'
import { Card, CardHeader } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { WeatherCard, weatherMeta } from '@/components/weather-card'
import { api } from '@/data/api'
import { formatTime } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { WeatherState } from '@/types'

const options: { state: WeatherState; icon: typeof Sun; body: string }[] = [
  { state: 'safe', icon: Sun, body: 'Normal delivery.' },
  { state: 'caution', icon: Wind, body: 'Slower flights, longer ETAs, ₱5 surcharge.' },
  { state: 'grounded', icon: CloudLightning, body: 'Blocks new orders, cancels and refunds active ones, recalls drones.' },
]

export default function AdminWeather() {
  const weather = useQuery(() => api.weather(), [], 30_000)
  const [busy, setBusy] = useState<WeatherState | 'clear' | null>(null)
  const w = weather.data

  async function apply(state: WeatherState) {
    setBusy(state)
    try {
      await api.setWeatherOverride(state)
      invalidate()
      toast(`Weather override applied: ${state.toUpperCase()} (2 hours).`)
    } catch (e) {
      toast(`Unable to apply weather override: ${errorMessage(e)}`, 'error')
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
      <div className="flex flex-col gap-6">
        <WeatherCard />
        {w ? (
          <Card className="p-5">
            <h2 className="font-semibold text-ink">Live reading vs. what drones obey</h2>
            <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
              <div className="rounded-xl bg-sunken p-3">
                <dt className="text-xs text-ink-3">Real conditions (Open-Meteo)</dt>
                <dd className="mt-1 font-semibold text-ink">{(w.real_safety_status ?? w.safety_status).toUpperCase()} · {w.real_condition ?? w.condition ?? '—'}</dd>
              </div>
              <div className="rounded-xl bg-sunken p-3">
                <dt className="text-xs text-ink-3">In effect</dt>
                <dd className="mt-1 font-semibold text-ink">{w.safety_status.toUpperCase()}{w.override_status ? ` · manual until ${w.override_until ? formatTime(w.override_until) : '—'}` : ' · live'}</dd>
              </div>
            </dl>
          </Card>
        ) : null}
      </div>

      <Card>
        <CardHeader title="Configure Campus Weather" description="An override lasts 2 hours, then live weather takes over again. Customers and vendors only see the result." />
        <div className="grid gap-3 p-5">
          {options.map((o) => {
            const active = w?.override_status === o.state
            const button = (onClick?: () => void) => (
              <Button variant={active ? 'primary' : 'secondary'} size="sm" loading={busy === o.state} disabled={active} onClick={onClick}>
                {active ? 'Active' : 'Apply'}
              </Button>
            )
            return (
              <div key={o.state} className={cn('flex items-center gap-4 rounded-xl p-4 shadow-[inset_0_0_0_1px_var(--line)]', active && 'shadow-[inset_0_0_0_2px_var(--brand)]')}>
                <span className={cn('grid size-10 shrink-0 place-items-center rounded-xl', weatherMeta[o.state].cls)}>
                  <o.icon aria-hidden className="size-5" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-ink">{weatherMeta[o.state].label}</p>
                  <p className="text-sm text-ink-3">{o.body}</p>
                </div>
                {o.state === 'grounded' && !active ? (
                  <ConfirmDialog trigger={button()} title="Ground every drone?" body="New orders are blocked. Active orders are cancelled and refunded, and drones fly back to base. Admins get one summary alert." confirmLabel="Ground the fleet" onConfirm={() => apply('grounded')} />
                ) : (
                  button(() => apply(o.state))
                )}
              </div>
            )
          })}
          <Button
            variant="ghost"
            className="mt-2 justify-self-start"
            disabled={!w?.override_status}
            loading={busy === 'clear'}
            icon={<Play aria-hidden className="size-4" />}
            onClick={async () => {
              setBusy('clear')
              try {
                await api.clearWeatherOverride()
                invalidate()
                toast('Live weather resumed.')
              } catch (e) {
                toast(errorMessage(e), 'error')
              } finally {
                setBusy(null)
              }
            }}
          >
            Resume live weather
          </Button>
          <p className="flex items-center gap-2 text-xs text-ink-3"><CloudSun aria-hidden className="size-3.5" />Live readings refresh every 15 minutes from the database job.</p>
        </div>
      </Card>
    </div>
  )
}
