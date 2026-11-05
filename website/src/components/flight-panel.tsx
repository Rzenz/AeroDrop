import { api } from '@/data/api'
import { deliveryStatusMeta } from '@/lib/format'
import { findHub, legProgress, phaseOf, positionFor, type Phase } from '@/lib/flight'
import { useQuery } from '@/lib/store'
import type { Order } from '@/types'
import { CampusMap } from './campus-map'
import TextShimmer from './forgeui/text-shimmer'
import { ProgressBar } from './orders'
import { Skeleton } from './ui/loader'
import { Badge, Card } from './ui/primitives'

const phaseCopy: Record<Phase, string> = {
  waiting: 'Ready and waiting for the next free drone',
  to_vendor: 'Flying to the vendor for pickup',
  to_customer: 'Carrying your package to the drop zone',
  between_trips: 'Returning to the vendor for the next load',
  arrived: 'Landed at the drop zone',
}

/**
 * Live map and flight stats for one order's delivery. Uses the app's leg
 * model: deliveries.progress is the current leg, and the drone sits where
 * its latest telemetry says (written by whichever client runs the simulator).
 */
export function FlightPanel({ order, mapClassName = 'h-80' }: { order: Order; mapClassName?: string }) {
  const locations = useQuery(() => api.locations())
  const d = order.delivery
  const flying = d?.status === 'assigning' || d?.status === 'in_transit'
  const telemetry = useQuery(() => (d && flying ? api.telemetry(d.id) : Promise.resolve(null)), [d?.id, flying], flying ? 3000 : undefined)

  if (!locations.data) return <Skeleton className={`${mapClassName} rounded-2xl`} />
  if (!d) return null
  const locs = locations.data
  const hub = findHub(locs)!
  const pickup = locs.find((l) => l.id === d.pickup_location_id) ?? hub
  const dropoff = locs.find((l) => l.id === (d.dropoff_location_id ?? order.delivery_location_id)) ?? hub
  const phase = phaseOf(d)
  const progress = legProgress(d)
  const live = telemetry.data
  const dronePos = live ? { latitude: live.latitude, longitude: live.longitude } : positionFor(phase, progress, hub, pickup, dropoff)
  const meta = deliveryStatusMeta[d.status]
  const inAir = phase === 'to_vendor' || phase === 'to_customer' || phase === 'between_trips'

  return (
    <Card className="overflow-hidden">
      <CampusMap
        label={`Map of the flight from ${pickup.name} to ${dropoff.name}`}
        locations={locs}
        route={{ from: hub, via: pickup, to: dropoff }}
        highlight={{ pickupId: pickup.id, dropoffId: dropoff.id }}
        drones={inAir || phase === 'arrived' ? [{ id: d.id, label: inAir ? 'Drone' : 'Delivered', active: inAir, ...dronePos }] : []}
        className={`${mapClassName} rounded-none`}
      />
      <div className="@container p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <Badge tone={meta.tone} dot>
              {meta.label}
            </Badge>
            {flying ? <TextShimmer className="mt-2 text-sm font-medium">{phaseCopy[phase]}</TextShimmer> : null}
          </div>
          {inAir ? <p className="font-mono text-sm font-semibold text-brand-ink tabular-nums">{phase === 'to_vendor' ? 'Leg 1 of 2' : phase === 'to_customer' ? 'Leg 2 of 2' : 'Between trips'}</p> : null}
        </div>
        {inAir || phase === 'arrived' ? <ProgressBar value={progress} label={phase === 'to_vendor' ? 'Progress to the vendor' : 'Progress to the drop-off'} className="mt-4" /> : null}
        <dl className="mt-4 grid grid-cols-2 gap-2 @lg:grid-cols-4">
          {[
            ['Pickup', pickup.name.replace(/^UCLM /, '')],
            ['Drop-off', dropoff.name.replace(/^UCLM /, '')],
            ['Trips', `${d.trips_completed}/${d.trips_required}`],
            // The app shows the raw telemetry value; rounding here is display only.
            ['Battery', live?.battery_level != null ? `${Math.round(live.battery_level)}%` : '—'],
          ].map(([k, v]) => (
            <div key={k} className="rounded-xl bg-sunken px-3 py-2">
              <dt className="text-[11px] text-ink-3">{k}</dt>
              <dd className="truncate text-sm font-semibold text-ink tabular-nums">{v}</dd>
            </div>
          ))}
        </dl>
        {phase === 'waiting' ? <p className="mt-3 text-sm text-ink-2">{phaseCopy.waiting}. It leaves as soon as one is charged.</p> : null}
      </div>
    </Card>
  )
}
