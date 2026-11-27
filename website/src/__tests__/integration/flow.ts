// Steps shared by the integration cases: open a page as a user, set up the
// pre-condition through the same backend calls the pages make, and play the
// ground-station bridge's part (python_script/aio.py) until a delivery reaches
// a state.
import { fireEvent, screen } from '@testing-library/react'
import { renderApp } from './app'
import { backendApi as api, bridge, db, signInAs, type Db } from './backend'

export { api, db }

/** Opens [path] with [who] signed in (null: signed out). */
export function openAs(who: string | null, path: string) {
  if (who) signInAs(who)
  else db.current.session = null
  return renderApp(path)
}

/** Runs [fn] as [who] without rendering anything, for pre-conditions. */
export async function as<T>(who: string, fn: () => Promise<T>): Promise<T> {
  const prev = db.current.session
  db.current.session = who
  try { return await fn() } finally { db.current.session = prev }
}

/** Signs in on the Sign In page with the seeded password. */
export function signInWith(email: string, password = 'AeroDrop#2026') {
  fireEvent.change(screen.getByLabelText('Email'), { target: { value: email } })
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: password } })
  fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))
}

/** Maria Santos orders [lines] from Kape Kanto for the Maritime Building; returns the order id. */
export async function customerOrders(lines: [string, number][] = [['latte', 1]]) {
  return as('maria', async () => {
    const items = lines.map(([id, quantity]) => { const p = db.current.products.find((x) => x.id === id)!; return { product_id: id, product_name: p.name, quantity, unit_price: p.price } })
    const q = await api.quoteOrderFee({ vendorId: 'kape', dropoffLocationId: 'maritime', items })
    return api.placeOrder({ vendorId: 'kape', dropoffLocationId: 'maritime', subtotal: q.subtotal, deliveryFee: q.deliveryFee, totalAmount: q.totalAmount, paymentMethod: 'gcash_simulated', items })
  })
}

/** An order that Kape Kanto has confirmed and is preparing. */
export async function preparingOrder() {
  const id = await customerOrders()
  await as('kape', () => api.setOrderStatus(id, 'confirmed'))
  await as('kape', () => api.setOrderStatus(id, 'preparing'))
  return id
}

/** An order Kape Kanto has marked ready, with DRN-001 dispatched. */
export async function dispatchedOrder() {
  const id = await preparingOrder()
  await as('kape', () => api.markOrderReady(id))
  return id
}

/**
 * Flies the dispatched delivery of [orderId] the way the bridge does, one
 * step at a time, until [done] holds: standby telemetry at the hub, takeoff
 * (confirm_package_pickup), in-flight telemetry towards the drop-off, the drop
 * (complete_delivery_order), the return leg, and landing (complete_drone_return).
 */
export async function fly(orderId: string, done: (d: Db) => boolean) {
  const d = db.current
  const dl = delivery(orderId)
  const hub = d.locations.find((l) => l.location_code === 'BASE-HUB')!
  const drop = d.locations.find((l) => l.id === dl.dropoff_location_id)!
  const at = (f: number) => ({ latitude: hub.latitude + (drop.latitude - hub.latitude) * f, longitude: hub.longitude + (drop.longitude - hub.longitude) * f })
  const point = (f: number, event: 'standby' | 'in_flight' | 'returning_to_base', progress: number | null) =>
    bridge.recordTelemetry({ deliveryId: dl.id, ...at(f), altitude: event === 'standby' ? 0 : 20, speed: event === 'standby' ? 0 : 5, battery: 90, signal: 98, heading: 45, event, progress })
  const steps: (() => Promise<void>)[] = [
    () => point(0, 'standby', 0),
    () => bridge.confirmPickup(dl.id),
    ...[0.25, 0.5, 0.75, 1].map((f) => () => point(f, 'in_flight', f)),
    () => bridge.completeDelivery(dl.id),
    ...[0.5, 0].map((f) => () => point(f, 'returning_to_base', null)),
    () => bridge.completeDroneReturn(dl.drone_id!),
  ]
  for (const step of steps) {
    if (done(db.current)) return
    await step()
  }
  if (!done(db.current)) throw new Error('The flight did not reach the expected state.')
}

export const delivery = (orderId: string) => db.current.deliveries.find((d) => d.order_id === orderId)!
export const order = (orderId: string) => db.current.orders.find((o) => o.id === orderId)!
