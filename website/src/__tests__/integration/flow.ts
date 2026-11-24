// Steps shared by the integration cases: open a page as a user, set up the
// pre-condition through the same backend calls the pages make, and run the
// drone flight module (lib/flight-sim.ts) until a delivery reaches a state.
import { fireEvent, screen } from '@testing-library/react'
import { vi } from 'vitest'
import { startFlightSimulator } from '@/lib/flight-sim'
import { renderApp } from './app'
import { backendApi as api, db, signInAs, type Db } from './backend'

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

/** Runs the drone flight module, 3 s per tick, until [done] holds. */
export async function fly(done: (d: Db) => boolean, maxTicks = 600) {
  vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'setTimeout', 'clearTimeout', 'Date'] })
  const prev = db.current.session
  db.current.session = 'admin'
  const flight = startFlightSimulator(api, 'admin', () => {})
  try {
    for (let i = 0; i < maxTicks && !done(db.current); i++) await vi.advanceTimersByTimeAsync(3000)
  } finally {
    flight.stop()
    db.current.session = prev
    vi.useRealTimers()
  }
  if (!done(db.current)) throw new Error('The flight did not reach the expected state.')
}

export const delivery = (orderId: string) => db.current.deliveries.find((d) => d.order_id === orderId)!
export const order = (orderId: string) => db.current.orders.find((o) => o.id === orderId)!
