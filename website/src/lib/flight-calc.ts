// Port of lib/core/services/drone_flight_calculator.dart and
// DeliveryNotifier._coordinatesForLocation. Keep the numbers identical to the
// app: both clients fly the same drone through the same database rows.

export const MAX_PAYLOAD_KG = 0.5
export const BASE_SPEED = 5.0 // m/s (~18 km/h)
export const BASE_DRAIN_NORMAL = 6.0 // battery % per leg
export const BASE_DRAIN_CAUTION = 8.5
export const WEATHER_CAUTION_SPEED_FACTOR = 0.7
export const MIN_DURATION_SECONDS = 15
export const MAX_DURATION_SECONDS = 60
export const TICK_SECONDS = 3

export type Coords = readonly [number, number] // (lat, lng), like the Dart record

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v))

/** latlong2's Distance() uses the haversine formula on a 6,371,000 m sphere. */
export function distanceMeters(a: Coords, b: Coords) {
  const R = 6371000
  const toRad = (d: number) => (d * Math.PI) / 180
  const dLat = toRad(b[0] - a[0])
  const dLng = toRad(b[1] - a[1])
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a[0])) * Math.cos(toRad(b[0])) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function effectiveSpeed({ isLoaded, payloadKg = 0, isCaution = false }: { isLoaded: boolean; payloadKg?: number; isCaution?: boolean }) {
  const payload = isLoaded ? clamp(payloadKg, 0, MAX_PAYLOAD_KG) : 0
  const ratio = clamp(payload / MAX_PAYLOAD_KG, 0, 1)
  return BASE_SPEED * (1 - 0.2 * ratio) * (isCaution ? WEATHER_CAUTION_SPEED_FACTOR : 1)
}

export function batteryDrain({ isLoaded, payloadKg = 0, isCaution = false }: { isLoaded: boolean; payloadKg?: number; isCaution?: boolean }) {
  const base = isCaution ? BASE_DRAIN_CAUTION : BASE_DRAIN_NORMAL
  const payload = isLoaded ? clamp(payloadKg, 0, MAX_PAYLOAD_KG) : 0
  return base * (1 + 0.4 * clamp(payload / MAX_PAYLOAD_KG, 0, 1))
}

export function durationSeconds(distance: number, speed: number) {
  if (speed <= 0) return MAX_DURATION_SECONDS
  return clamp(distance / speed, MIN_DURATION_SECONDS, MAX_DURATION_SECONDS)
}

export const progressStep = (duration: number, tick = TICK_SECONDS) => (duration <= 0 ? 1 : tick / duration)

export function remainingSeconds(progress: number, totalDuration: number) {
  const p = clamp(progress, 0, 1)
  return p >= 1 ? 0 : Math.round((1 - p) * totalDuration)
}

export function formatEta(secs: number) {
  if (secs <= 0) return '0 mins'
  if (secs < 60) return `${secs} secs`
  return `${Math.ceil(secs / 60)} mins`
}

export const DEFAULT_HUB: Coords = [10.325152, 123.953046]

/**
 * DeliveryNotifier._coordinatesForLocation: the simulator places buildings by
 * name, with these fixed coordinates, matching on either containment.
 */
export function coordinatesForLocation(name: string | null | undefined, hub: Coords): Coords {
  if (!name) return [10.32521, 123.953201]
  const q = name.toLowerCase()
  const table: [string, Coords][] = [
    ['old building', [10.32521, 123.953201]],
    ['main', [10.32521, 123.953201]],
    ['uclm main', [10.32521, 123.953201]],
    ['annex 2 building', [10.325633, 123.95377]],
    ['annex-2', [10.325633, 123.95377]],
    ['annex 2', [10.325633, 123.95377]],
    ['basic education building', [10.325133, 123.953853]],
    ['basic-ed', [10.325133, 123.953853]],
    ['basic education', [10.325133, 123.953853]],
    ['basic ed', [10.325133, 123.953853]],
    ['maritime building', [10.326184, 123.954843]],
    ['maritime', [10.326184, 123.954843]],
    ['base hub', hub],
    ['base-hub', hub],
  ]
  for (const [key, c] of table) if (q.includes(key) || key.includes(q)) return c
  return [10.32521, 123.953201]
}
