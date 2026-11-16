import type { CampusLocation, Delivery, Order } from '@/types'

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

/** OrderModel.pinnedDropoffName: a pinned drop-off's name when the customer gave no description. */
export const PINNED_DROPOFF_NAME = 'Pinned drop-off'

type DropoffFields = Pick<Order, 'id' | 'custom_dropoff_lat' | 'custom_dropoff_lng' | 'custom_dropoff_label'>

/** OrderModel.hasCustomDropoff: the customer pinned the drop-off on the map instead of choosing a campus point. */
export const isPinnedDropoff = (o: DropoffFields) => o.custom_dropoff_lat != null

/** The customer's description of a pinned drop-off, if they gave one. */
export const pinnedDropoffLabel = (o: DropoffFields) => o.custom_dropoff_label?.trim() || null

/** A pinned drop-off as a map point, or null for a campus drop-off (or unreadable coordinates). */
export function pinnedDropoff(o: DropoffFields): CampusLocation | null {
  if (!isPinnedDropoff(o)) return null
  const latitude = Number(o.custom_dropoff_lat)
  const longitude = Number(o.custom_dropoff_lng)
  if (o.custom_dropoff_lng == null || !Number.isFinite(latitude) || !Number.isFinite(longitude)) return null
  return { id: `pinned:${o.id}`, name: pinnedDropoffLabel(o) ?? PINNED_DROPOFF_NAME, location_code: 'PINNED', latitude, longitude }
}

/** Where an order is going: the pinned point, else the delivery's or the order's campus location. */
export function orderDropoff(o: DropoffFields & Pick<Order, 'delivery_location_id' | 'delivery'>, locs: CampusLocation[]): CampusLocation | undefined {
  return pinnedDropoff(o) ?? locs.find((l) => l.id === (o.delivery?.dropoff_location_id ?? o.delivery_location_id))
}

/** The drop-off's display name; a pinned order is named even before the campus list loads. */
export function orderDropoffName(o: DropoffFields & Pick<Order, 'delivery_location_id' | 'delivery'>, locs: CampusLocation[] | undefined): string | undefined {
  if (isPinnedDropoff(o)) return pinnedDropoffLabel(o) ?? PINNED_DROPOFF_NAME
  return locs ? orderDropoff(o, locs)?.name : undefined
}
