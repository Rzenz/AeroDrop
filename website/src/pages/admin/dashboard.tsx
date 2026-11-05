import { CheckCircle2, Clock, PlaneTakeoff, Radar } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { CampusMap } from '@/components/campus-map'
import StatsCard from '@/components/forgeui/stats-card'
import { OrderRow, StatTile } from '@/components/orders'
import { Skeleton } from '@/components/ui/loader'
import { Card, CardHeader, EmptyState } from '@/components/ui/primitives'
import { weatherMeta } from '@/components/weather-card'
import { api } from '@/data/api'
import { droneMarkers } from '@/lib/fleet'
import { effectiveStatus, formatPeso } from '@/lib/format'
import { readLocal, useQuery } from '@/lib/store'
import { ADMIN_PREFS_KEY } from './settings'
import { cn } from '@/lib/utils'

export default function AdminDashboard() {
  const orders = useQuery(() => api.orders(), [], 4000)
  const drones = useQuery(() => api.drones(), [], 4000)
  const locations = useQuery(() => api.locations())
  const zones = useQuery(() => api.zones())
  const weather = useQuery(() => api.weather(), [], 60_000)
  const vendors = useQuery(() => api.vendors())
  const telemetry = useQuery(() => api.fleetTelemetry(), [], 3000)

  // Tick the radar between polls so in-flight drones glide.
  const [, setTick] = useState(0)
  const live = readLocal(ADMIN_PREFS_KEY, { liveTelemetry: true }).liveTelemetry !== false
  useEffect(() => {
    if (!live) return
    const id = setInterval(() => setTick((t) => t + 1), 1000)
    return () => clearInterval(id)
  }, [live])

  const all = orders.data ?? []
  const withDelivery = all.filter((o) => o.delivery)
  // Leg 1 (assigning) and leg 2 (in_transit) are both in the air.
  const inFlight = withDelivery.filter((o) => ['assigning', 'in_transit'].includes(o.delivery!.status)).length
  const waiting = withDelivery.filter((o) => o.delivery!.status === 'pending' || (o.delivery!.status === 'assigning' && !o.delivery!.drone_id)).length
  // Same definition as Analytics: delivered vs. cancelled or rejected orders.
  const delivered = all.filter((o) => effectiveStatus(o) === 'delivered').length
  const failed = all.filter((o) => ['cancelled', 'rejected'].includes(effectiveStatus(o))).length
  const success = delivered + failed ? Math.round((delivered / (delivered + failed)) * 100) : null
  const fleet = drones.data ?? []
  const online = fleet.filter((d) => !['offline', 'maintenance'].includes(d.status)).length

  // Top vendor this week, for the ForgeUI stats card.
  const weekAgo = Date.now() - 7 * 86_400_000
  const byVendor = new Map<string, number>()
  all.filter((o) => effectiveStatus(o) === 'delivered' && Date.parse(o.created_at) > weekAgo).forEach((o) => o.vendor_id && byVendor.set(o.vendor_id, (byVendor.get(o.vendor_id) ?? 0) + o.subtotal))
  const ranked = [...byVendor.entries()].sort((a, b) => b[1] - a[1])
  const vendorById = new Map((vendors.data ?? []).map((v) => [v.id, v]))
  const person = (e?: [string, number]) => (e ? { name: vendorById.get(e[0])?.business_name ?? 'Vendor', value: formatPeso(e[1]), image: vendorById.get(e[0])?.business_logo_url } : undefined)

  const w = weather.data

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-xs font-semibold tracking-wide text-brand uppercase">Autonomous network</p>
          <p className="text-sm text-ink-2">Real-time fleet & delivery overview</p>
        </div>
        {w ? (
          <Link to="/admin/weather" className={cn('inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-bold', weatherMeta[w.safety_status].cls)}>
            Campus {weatherMeta[w.safety_status].label}
            {w.override_status ? ' · override' : ''}
          </Link>
        ) : null}
      </div>

      <section aria-label="Fleet status" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile label="Active Flights" value={orders.loading ? '–' : inFlight} hint="In the air right now" icon={<PlaneTakeoff />} />
        <StatTile label="Fleet Online" value={drones.loading ? '–' : `${online}/${fleet.length}`} hint={`${fleet.filter((d) => d.status === 'available').length} available`} icon={<Radar />} />
        <StatTile label="Awaiting" value={orders.loading ? '–' : waiting} hint="Ready, waiting for a drone" icon={<Clock />} />
        <StatTile label="Success Rate" value={success == null ? '—' : `${success}%`} hint={`${delivered} delivered · ${failed} cancelled or rejected`} icon={<CheckCircle2 />} />
      </section>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
        <Card className="overflow-hidden">
          <CardHeader title="Campus Drone Radar" description="Live positions, routes and no-fly zones" className="pb-4" action={<Link to="/admin/drones" className="text-sm font-semibold text-brand-ink hover:underline">Fleet</Link>} />
          {locations.data && drones.data ? (
            <CampusMap label="Campus map with drone positions" locations={locations.data} zones={(zones.data ?? []).filter((z) => z.is_active)} drones={droneMarkers(drones.data, all, locations.data, telemetry.data)} className="h-[420px] rounded-none" />
          ) : (
            <Skeleton className="h-[420px] rounded-none" />
          )}
        </Card>
        {ranked.length ? (
          <StatsCard title="Top vendor this week" description="By delivered revenue. Hover or focus to see the runner-up." metric="Revenue" first={person(ranked[0])!} second={person(ranked[1])} />
        ) : (
          <Card className="grid place-items-center p-6 text-center text-sm text-ink-3">Delivered orders this week will rank vendors here.</Card>
        )}
      </div>

      <Card>
        <CardHeader title="Recent Deliveries" action={<Link to="/admin/deliveries" className="text-sm font-semibold text-brand-ink hover:underline">See all</Link>} />
        <div className="p-2">
          {withDelivery.length ? (
            <ul>{withDelivery.slice(0, 6).map((o) => <OrderRow key={o.id} order={o} to={`/admin/deliveries/details?id=${o.delivery!.id}`} perspective="admin" />)}</ul>
          ) : orders.loading ? (
            <Skeleton className="m-3 h-40" />
          ) : (
            <EmptyState title="No deliveries yet" body="They appear here as soon as a vendor marks an order ready." />
          )}
        </div>
      </Card>
    </div>
  )
}
