import type { MapDrone } from '@/components/campus-map'
import type { Telemetry } from '@/data/api'
import type { CampusLocation, Drone, Order } from '@/types'
import { findHub, legProgress, phaseOf, positionFor } from './flight'

/**
 * Where each drone is right now, like the app's radar: its latest telemetry
 * point when there is one, otherwise placed on its current leg, otherwise at
 * the hub.
 */
export function droneMarkers(drones: Drone[], orders: Order[], locs: CampusLocation[], telemetry: (Telemetry & { drone_id: string })[] = []): MapDrone[] {
  const hub = findHub(locs)
  if (!hub) return []
  return drones
    .filter((d) => d.status !== 'offline')
    .map((d) => {
      const o = orders.find((x) => x.delivery?.drone_id === d.id && (x.delivery.status === 'assigning' || x.delivery.status === 'in_transit'))
      const busy = !!o || d.status === 'returning'
      const t = telemetry.find((x) => x.drone_id === d.id)
      const label = o ? `${d.drone_code} · ${o.vendor_name ?? 'delivery'}` : d.status === 'returning' ? `${d.drone_code} · returning` : d.drone_code
      if (t && busy) return { id: d.id, label, active: true, latitude: t.latitude, longitude: t.longitude }
      if (o?.delivery) {
        const pickup = locs.find((l) => l.id === o.delivery!.pickup_location_id) ?? hub
        const dropoff = locs.find((l) => l.id === (o.delivery!.dropoff_location_id ?? o.delivery_location_id)) ?? hub
        return { id: d.id, label, active: true, ...positionFor(phaseOf(o.delivery), legProgress(o.delivery), hub, pickup, dropoff) }
      }
      return { id: d.id, label, active: d.status === 'returning', latitude: hub.latitude, longitude: hub.longitude }
    })
}
