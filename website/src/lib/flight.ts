import type { CampusLocation, Delivery } from '@/types'

type Pt = { latitude: number; longitude: number }

// The app's flight model (DeliveryNotifier): deliveries.progress is the
// progress of the CURRENT LEG, not of the whole trip.
//   status 'assigning'  -> leg 1, hub to vendor (empty)
//   status 'in_transit' -> leg 2, vendor to customer (loaded)
//   in_transit with trips left and trips_completed > 0 -> between trips,
//     the drone is shuttling back and progress is 0

export type Phase = 'waiting' | 'to_vendor' | 'to_customer' | 'between_trips' | 'arrived'

export function phaseOf(d: Pick<Delivery, 'status' | 'trips_completed' | 'trips_required' | 'drone_id' | 'progress'>): Phase {
  if (d.status === 'delivered') return 'arrived'
  if (d.status === 'assigning') return d.drone_id ? 'to_vendor' : 'waiting'
  if (d.status === 'in_transit') return d.trips_completed > 0 && d.trips_completed < d.trips_required && d.progress === 0 ? 'between_trips' : 'to_customer'
  return 'waiting'
}

/** Progress of the current leg, 0..1. */
export const legProgress = (d: Pick<Delivery, 'status' | 'progress'>) => (d.status === 'delivered' ? 1 : Math.min(1, Math.max(0, d.progress ?? 0)))

const lerp = (a: Pt, b: Pt, t: number): Pt => ({
  latitude: a.latitude + (b.latitude - a.latitude) * t,
  longitude: a.longitude + (b.longitude - a.longitude) * t,
})

/** Where the drone is on its current leg, when no telemetry point is available. */
export function positionFor(phase: Phase, progress: number, hub: Pt, pickup: Pt, dropoff: Pt): Pt {
  if (phase === 'to_vendor') return lerp(hub, pickup, progress)
  if (phase === 'to_customer') return lerp(pickup, dropoff, progress)
  if (phase === 'arrived') return dropoff
  return hub
}

export const findHub = (locs: CampusLocation[]) =>
  locs.find((l) => /BASE[-_]HUB/i.test(l.location_code) || /base hub/i.test(l.name)) ?? locs[0]

export const isHub = (l: CampusLocation) => /BASE[-_]HUB/i.test(l.location_code) || /base hub/i.test(l.name)
