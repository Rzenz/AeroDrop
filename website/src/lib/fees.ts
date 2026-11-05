// Port of lib/core/services/delivery_fee_calculator.dart. Keep the numbers in
// step with the app: the database re-checks what the client sends.

export const BASE_FEE = 15
export const DISTANCE_RATE_PER_KM = 40
export const WEIGHT_RATE_PER_KG = 10
export const MAX_PAYLOAD_KG = 0.5
export const MAX_TRIPS = 2
export const CAUTION_SURCHARGE = 5
export const EXTRA_TRIP_FEE = 25

export const tripsForWeight = (kg: number) => Math.max(1, Math.ceil(kg / MAX_PAYLOAD_KG - 1e-9))

const round2 = (n: number) => Math.round(n * 100) / 100

export interface FeeBreakdown {
  base: number
  distanceKm: number
  distanceFee: number
  weightKg: number
  weightFee: number
  tripFee: number
  weatherFee: number
  trips: number
  total: number
}

export function deliveryFee(opts: { distanceKm: number; weightKg: number; caution: boolean }): FeeBreakdown {
  const trips = tripsForWeight(opts.weightKg)
  const dist = opts.distanceKm > 0.005 ? opts.distanceKm : 0
  const distanceFee = round2(dist * DISTANCE_RATE_PER_KM * trips)
  const weightKg = Math.min(Math.max(opts.weightKg, 0), MAX_PAYLOAD_KG * MAX_TRIPS)
  const weightFee = round2(weightKg * WEIGHT_RATE_PER_KG)
  const tripFee = EXTRA_TRIP_FEE * (trips - 1)
  const weatherFee = opts.caution ? CAUTION_SURCHARGE : 0
  const total = round2(Math.max(BASE_FEE, BASE_FEE + distanceFee + weightFee + tripFee + weatherFee))
  return { base: BASE_FEE, distanceKm: dist, distanceFee, weightKg, weightFee, tripFee, weatherFee, trips, total }
}

/** Great-circle distance in km. */
export function haversineKm(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const R = 6371
  const toRad = (d: number) => (d * Math.PI) / 180
  const dLat = toRad(b.latitude - a.latitude)
  const dLon = toRad(b.longitude - a.longitude)
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLon / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(h))
}
