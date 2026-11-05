import { BatteryCharging, PlaneTakeoff, Zap } from 'lucide-react'
import { useState } from 'react'
import { CampusMap } from '@/components/campus-map'
import { Meter } from '@/components/charts'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Badge, Card, CardHeader, EmptyState } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { droneMarkers } from '@/lib/fleet'
import { droneStatusMeta, timeAgo } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import type { Drone } from '@/types'

// Same controls as the app's Drone Fleet screen: the fleet is the single
// registered drone (DRN-001), and the admin's one action is Recharge.
// Flight states are set by the dispatcher and the flight simulator.

export default function Fleet() {
  const drones = useQuery(() => api.drones(), [], 5000)
  const orders = useQuery(() => api.orders(), [], 5000)
  const locations = useQuery(() => api.locations())
  const telemetry = useQuery(() => api.fleetTelemetry(), [], 3000)
  const [busy, setBusy] = useState<string | null>(null)

  async function recharge(d: Drone) {
    setBusy(d.id)
    try {
      await api.rechargeDrone(d.id)
      invalidate()
      toast(`${d.drone_code} recharged to 100% and available.`)
    } catch (e) {
      toast(errorMessage(e), 'error')
    } finally {
      setBusy(null)
    }
  }

  const fleet = drones.data ?? []
  return (
    <div className="grid gap-6 2xl:grid-cols-[minmax(0,1fr)_420px]">
      <div className="flex flex-col gap-4">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {drones.loading
            ? [0].map((i) => <Skeleton key={i} className="h-56 rounded-2xl" />)
            : fleet.map((d) => {
                const meta = droneStatusMeta[d.status]
                const flight = orders.data?.find((o) => o.delivery?.drone_id === d.id && ['assigning', 'in_transit'].includes(o.delivery.status))
                const inUse = !!flight || ['assigned', 'busy', 'returning'].includes(d.status)
                const low = d.battery_level < 25
                return (
                  <Card key={d.id} className="flex flex-col p-5">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="font-mono text-xs text-ink-3">{d.drone_code}</p>
                        <p className="font-semibold text-ink">{d.drone_name ?? 'Unnamed drone'}</p>
                        <p className="text-xs text-ink-3">{d.model} · {d.max_payload_kg} kg payload</p>
                      </div>
                      <Badge tone={meta.tone} dot>{meta.label}</Badge>
                    </div>
                    <div className="mt-5">
                      <div className="mb-1.5 flex items-center justify-between text-xs">
                        <span className="flex items-center gap-1 text-ink-2"><BatteryCharging aria-hidden className="size-3.5" /> Battery</span>
                        <span className={`font-semibold tabular-nums ${low ? 'text-danger' : 'text-ink'}`}>{Math.round(d.battery_level)}%{low ? ' · low' : ''}</span>
                      </div>
                      <Meter value={d.battery_level} tone={low ? 'critical' : d.battery_level < 50 ? 'warning' : 'good'} label={`${d.drone_code} battery`} />
                    </div>
                    <p className="mt-4 text-sm text-ink-2">
                      {flight ? <>Flying for <b className="text-ink">{flight.vendor_name}</b></> : d.status === 'returning' ? 'Returning to the Campus Base Hub.' : d.status === 'available' ? 'At the hub, ready to dispatch.' : `Updated ${timeAgo(d.updated_at)}`}
                    </p>
                    <Button
                      variant="secondary"
                      className="mt-auto"
                      loading={busy === d.id}
                      disabled={inUse || d.battery_level >= 100}
                      title={inUse ? 'Available once the drone is back at the hub' : undefined}
                      icon={<Zap aria-hidden className="size-4" />}
                      onClick={() => recharge(d)}
                    >
                      {d.battery_level >= 100 ? 'Fully charged' : 'Recharge'}
                    </Button>
                  </Card>
                )
              })}
        </div>
        {!drones.loading && !fleet.length ? <Card><EmptyState icon={<PlaneTakeoff aria-hidden className="size-5" />} title="No Drones Registered" body="Register DRN-001 in the database to start dispatching." /></Card> : null}
      </div>
      <Card className="overflow-hidden 2xl:sticky 2xl:top-20 2xl:self-start">
        <CardHeader title="Positions" className="pb-4" />
        {locations.data ? <CampusMap label="Fleet positions on campus" locations={locations.data} drones={droneMarkers(fleet, orders.data ?? [], locations.data, telemetry.data)} className="h-96 rounded-none" /> : <Skeleton className="h-96 rounded-none" />}
      </Card>
    </div>
  )
}
