// Payload limits, as in lib/core/services/delivery_fee_calculator.dart. These
// answer weight questions (will this cart fly, in how many trips) without a
// network call.
//
// Prices are not here on purpose. What an order costs comes only from the
// server's quote_order_fee(), the same function place_order charges with, so
// the figure shown and the figure charged cannot drift apart.

export const MAX_PAYLOAD_KG = 0.5
export const MAX_TRIPS = 2

export const tripsForWeight = (kg: number) => Math.max(1, Math.ceil(kg / MAX_PAYLOAD_KG - 1e-9))
