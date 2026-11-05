// Port of DeliveryNotifier._startSimulation (lib/core/providers/delivery_provider.dart).
//
// The app flies the drone from the client: every signed-in device ticks every
// 3 seconds, advancing leg 1 (hub -> vendor) and leg 2 (vendor -> customer)
// for the deliveries it can see, and whichever device holds the drone's
// simulation lease flies leg 3 (back to the hub, or to the vendor between
// trips). The website runs the same loop against the same RPCs, so a web tab
// moves a delivery along exactly as an open phone would.

import type { Api, SimDelivery } from '@/data/api'
import type { Drone, Role } from '@/types'
import {
  batteryDrain,
  coordinatesForLocation,
  distanceMeters,
  durationSeconds,
  effectiveSpeed,
  progressStep,
  TICK_SECONDS,
  type Coords,
} from './flight-calc'

const clamp01 = (v: number) => Math.min(1, Math.max(0, v))
const hasTripsRemaining = (d: SimDelivery) => d.trips_completed < d.trips_required

export interface SimHandle {
  stop(): void
}

// Battery at the start of each delivery. Shared across simulator restarts in
// this tab, like the notifier's _deliveryStartBatteries (seeded on dispatch).
const deliveryStartBatteries = new Map<string, number>()

/**
 * The vendor's "Ready for drone pickup" action. Like the app's dispatch path,
 * it records the drone's real battery so Leg 1 drains from that level
 * instead of the 98% fallback.
 */
export async function markOrderReadyAndDispatch(api: Api, orderId: string): Promise<string> {
  const message = await api.markOrderReady(orderId)
  try {
    const order = await api.order(orderId)
    const d = order?.delivery
    if (d?.drone_id) {
      const drone = (await api.drones()).find((x) => x.id === d.drone_id)
      if (drone) deliveryStartBatteries.set(d.id, drone.battery_level)
    }
  } catch {
    // The simulator falls back to 98%, as the app does on other devices.
  }
  return message
}

export function startFlightSimulator(api: Api, role: Role, onChange: () => void): SimHandle {
  // Per-session bookkeeping, the same maps the Dart notifier keeps.
  const leg3StartBatteries = new Map<string, number>()
  const confirmingPickup = new Set<string>()
  const completingDeliveries = new Set<string>()
  const completingReturnDrones = new Set<string>()
  const leg3Progress = new Map<string, number>()
  const leg3Origin = new Map<string, Coords>()
  const lastDeliveryIdForDrone = new Map<string, string>()
  const leaseWriteFailures = new Map<string, number>()
  let lastTelemetryWrite = 0
  let running = false
  let stopped = false
  let lastStaleCheck = 0

  const warn = (where: string) => (e: unknown) => console.debug(`[flight-sim] ${where}:`, e)

  async function tick() {
    if (running || stopped) return // never overlap ticks
    running = true
    try {
      if (!(await api.currentUserId())) return
      const [deliveries, drones, weather, hub] = await Promise.all([api.simDeliveries(), api.drones(), api.weather(), api.hubCoords()])
      const isCaution = weather.safety_status === 'caution'

      // Release bookkeeping once the server has moved on (same three cleanups).
      for (const id of completingReturnDrones) if (drones.some((d) => d.id === id && d.status !== 'returning')) completingReturnDrones.delete(id)
      for (const id of confirmingPickup) if (deliveries.some((d) => d.id === id && d.status !== 'assigning')) confirmingPickup.delete(id)
      for (const id of completingDeliveries) if (deliveries.some((d) => d.id === id && (d.status === 'delivered' || d.status === 'assigning'))) completingDeliveries.delete(id)

      const active = deliveries.filter((d) => (d.status === 'assigning' || d.status === 'in_transit') && !completingDeliveries.has(d.id))
      const returningDrone = drones.find((d) => d.status === 'returning' && !completingReturnDrones.has(d.id))

      // SharedDroneRadar: every 15s, ask the server to free a drone stuck returning.
      if (returningDrone && Date.now() - lastStaleCheck > 15_000) {
        lastStaleCheck = Date.now()
        api.recoverStaleReturningDrone(returningDrone.id).then((r) => r && onChange(), warn('recover_stale_returning_drone'))
      }

      if (!active.length && !returningDrone) return
      // Single-writer coordination: skip if this client wrote under 2.2s ago.
      if (Date.now() - lastTelemetryWrite < 2200) return
      lastTelemetryWrite = Date.now()

      const droneId = returningDrone?.id ?? drones[0]?.id
      if (!droneId) return
      let changed = false

      for (const delivery of active) {
        if (completingDeliveries.has(delivery.id)) continue
        const vendorLoc = coordinatesForLocation(delivery.pickup_name, hub)
        const customerLoc = coordinatesForLocation(delivery.dropoff_name, hub)

        if (delivery.status === 'assigning') {
          // ── Leg 1: hub -> vendor, empty ──
          const speed = effectiveSpeed({ isLoaded: false, isCaution })
          const duration = durationSeconds(distanceMeters(hub, vendorLoc), speed)
          const drain = batteryDrain({ isLoaded: false, isCaution })

          if (delivery.progress >= 1) {
            // Recovery: already at the vendor, confirm without telemetry.
            await confirmPickup(delivery)
            changed = true
            continue
          }
          const p = clamp01(clamp01(delivery.progress) + progressStep(duration, TICK_SECONDS))
          const lat = hub[0] + (vendorLoc[0] - hub[0]) * p
          const lng = hub[1] + (vendorLoc[1] - hub[1]) * p
          const battery = clampBattery((deliveryStartBatteries.get(delivery.id) ?? 98) - drain * p)
          lastDeliveryIdForDrone.set(droneId, delivery.id)
          leg3Origin.set(droneId, [lat, lng])

          if (p >= 1) {
            await confirmPickup(delivery)
          } else {
            api.recordTelemetry({ deliveryId: delivery.id, latitude: lat, longitude: lng, altitude: p > 0.85 ? 1.5 : 15, speed, battery, signal: 98, heading: 90, event: 'traveling_to_pickup', progress: p }).catch(warn('pickup telemetry'))
            api.setDroneBattery(droneId, battery).catch(warn('drone battery'))
          }
          changed = true
        } else if (
          delivery.status === 'in_transit' &&
          // Between trips the delivery stays in_transit while the drone flies
          // home to reload; flying leg 2 then would complete a trip never made.
          !(delivery.trips_completed > 0 && hasTripsRemaining(delivery) && drones.some((d) => d.status === 'returning' || d.status === 'available'))
        ) {
          // ── Leg 2: vendor -> customer, loaded ──
          const speed = effectiveSpeed({ isLoaded: true, payloadKg: delivery.payload_kg, isCaution })
          const duration = durationSeconds(distanceMeters(vendorLoc, customerLoc), speed)
          const drain = batteryDrain({ isLoaded: true, payloadKg: delivery.payload_kg, isCaution })

          if (delivery.progress >= 1) {
            const fallbackStart = deliveryStartBatteries.get(delivery.id) ?? 98 - drain
            await completeDelivery(delivery, customerLoc, clampBattery(fallbackStart - drain), droneId)
            changed = true
            continue
          }
          const p = clamp01(clamp01(delivery.progress) + progressStep(duration, TICK_SECONDS))
          const lat = vendorLoc[0] + (customerLoc[0] - vendorLoc[0]) * p
          const lng = vendorLoc[1] + (customerLoc[1] - vendorLoc[1]) * p
          const battery = clampBattery((deliveryStartBatteries.get(delivery.id) ?? 98 - drain) - drain * p)
          lastDeliveryIdForDrone.set(droneId, delivery.id)
          leg3Origin.set(droneId, [lat, lng])

          if (p >= 1) {
            await completeDelivery(delivery, customerLoc, battery, droneId)
          } else if (!completingDeliveries.has(delivery.id)) {
            api.recordTelemetry({ deliveryId: delivery.id, latitude: lat, longitude: lng, altitude: p > 0.85 ? 0.5 : 15, speed, battery, signal: 98, heading: 90, event: 'in_flight', progress: p }).catch(warn('transit telemetry'))
            api.setDroneBattery(droneId, battery).catch(warn('drone battery'))
          }
          changed = true
        }
      }

      // ── Leg 3: back to the hub (or to the vendor between trips), empty ──
      if (returningDrone) {
        if (await flyLeg3(returningDrone, deliveries, hub, isCaution)) changed = true
      }
      if (changed) onChange()
    } catch (e) {
      warn('tick')(e)
    } finally {
      running = false
    }
  }

  async function confirmPickup(delivery: SimDelivery) {
    if (confirmingPickup.has(delivery.id)) return
    confirmingPickup.add(delivery.id)
    try {
      await api.confirmPickup(delivery.id)
    } catch (e) {
      warn('confirm_package_pickup')(e)
      confirmingPickup.delete(delivery.id)
    }
  }

  async function completeDelivery(delivery: SimDelivery, customerLoc: Coords, battery: number, droneId: string) {
    if (completingDeliveries.has(delivery.id)) return
    completingDeliveries.add(delivery.id)
    deliveryStartBatteries.delete(delivery.id)
    lastDeliveryIdForDrone.set(droneId, delivery.id)
    leg3Origin.set(droneId, customerLoc)
    leg3Progress.set(droneId, 0)
    leg3StartBatteries.set(droneId, battery)
    try {
      await api.completeDelivery(delivery.id)
      // DroneNotifier.updateStatus(..., returning), as the app does after completing.
      await api.setDroneStatus(droneId, 'returning')
    } catch (e) {
      warn('complete_delivery_order')(e)
      completingDeliveries.delete(delivery.id)
    }
  }

  async function flyLeg3(drone: Drone, deliveries: SimDelivery[], hub: Coords, isCaution: boolean): Promise<boolean> {
    const droneId = drone.id
    let deliveryId =
      lastDeliveryIdForDrone.get(droneId) ??
      // A multi-trip delivery between trips is the flight in progress.
      deliveries.find((d) => d.drone_id && d.status === 'in_transit' && d.trips_completed > 0 && hasTripsRemaining(d))?.id
    if (!deliveryId) {
      const finished = deliveries
        .filter((d) => d.drone_id === droneId && (d.status === 'delivered' || d.status === 'cancelled'))
        .sort((a, b) => (b.delivered_at ?? b.created_at).localeCompare(a.delivered_at ?? a.created_at))
      deliveryId = finished[0]?.id ?? (await api.lastFinishedDeliveryForDrone(droneId).catch(() => null)) ?? undefined
    }
    if (!deliveryId) return false

    // Only an admin, or the order's customer or vendor, may write this telemetry.
    const authorized = role === 'admin' || deliveries.some((d) => d.id === deliveryId)
    const lastFailure = leaseWriteFailures.get(droneId)
    const backoff = lastFailure != null && Date.now() - lastFailure < 15_000
    const hasLease = authorized && !backoff ? await api.claimSimLease(droneId).catch(() => false) : false
    if (!hasLease) return false

    const shuttle = deliveries.find((d) => d.id === deliveryId && d.status === 'in_transit' && d.trips_completed > 0 && hasTripsRemaining(d))
    const destination = shuttle ? coordinatesForLocation(shuttle.pickup_name, hub) : hub
    const start: Coords = leg3Origin.get(droneId) ?? [10.32521, 123.953201]

    const speed = effectiveSpeed({ isLoaded: false, isCaution })
    const duration = durationSeconds(distanceMeters(start, destination), speed)
    const drain = batteryDrain({ isLoaded: false, isCaution })
    const p = clamp01(clamp01(leg3Progress.get(droneId) ?? 0) + progressStep(duration, TICK_SECONDS))
    leg3Progress.set(droneId, p)
    const lat = start[0] + (destination[0] - start[0]) * p
    const lng = start[1] + (destination[1] - start[1]) * p
    if (!leg3StartBatteries.has(droneId)) leg3StartBatteries.set(droneId, drone.battery_level)
    const battery = clampBattery(leg3StartBatteries.get(droneId)! - drain * p)

    try {
      // No progress: the delivery may still be in_transit between trips.
      await api.recordTelemetry({ deliveryId, latitude: lat, longitude: lng, altitude: p > 0.85 ? 0 : 15, speed, battery, signal: 98, heading: 270, event: 'returning_to_base', progress: null })
      leaseWriteFailures.delete(droneId)
    } catch (e) {
      warn('leg 3 telemetry')(e)
      leaseWriteFailures.set(droneId, Date.now()) // let another client take over for 15s
    }
    api.setDroneBattery(droneId, battery).catch(warn('drone battery'))

    if (p >= 1) {
      completingReturnDrones.add(droneId)
      leg3Progress.delete(droneId)
      leg3Origin.delete(droneId)
      lastDeliveryIdForDrone.delete(droneId)
      leaseWriteFailures.delete(droneId)
      leg3StartBatteries.delete(droneId)
      if (shuttle) {
        // The next trip drains from the battery the drone actually has left.
        deliveryStartBatteries.set(shuttle.id, battery)
        try {
          await api.arriveAtVendorForNextTrip(shuttle.id)
          await api.setDroneStatus(droneId, 'assigned')
        } catch (e) {
          warn('arrive_at_vendor_for_next_trip')(e)
          // Fall back to the hub route: freeing the drone lets the server resume from the hub.
          await api.completeDroneReturn(droneId).catch(warn('complete_drone_return'))
        }
      } else {
        await api.completeDroneReturn(droneId).catch(warn('complete_drone_return'))
      }
    }
    return true
  }

  const id = setInterval(() => void tick(), TICK_SECONDS * 1000)
  void tick()
  return {
    stop() {
      stopped = true
      clearInterval(id)
    },
  }
}

const clampBattery = (v: number) => Math.min(100, Math.max(0, v))
