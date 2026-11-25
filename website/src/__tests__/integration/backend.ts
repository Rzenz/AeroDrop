// In-memory AeroDrop backend for the integration tests.
//
// One shared store stands in for the Supabase tables, and the functions below
// follow the same rules as the database functions the website calls
// (place_order, vendor_mark_order_ready, confirm_package_pickup,
// complete_delivery_order, submit_order_reviews, ...). Pages from different
// modules read and write the same store, so a change made in one module can
// be checked in the next one, as a different signed-in user if needed.
import { vi } from 'vitest'
import type { Api, PlaceOrderInput, ProductInput, SimDelivery, TelemetryInput } from '@/data/api'
import type {
  AppNotification, CampusLocation, Delivery, Drone, NoFlyZone, Order, OrderMessage, Product, Profile, StatusLog, SupportMessage, SupportReport, Weather,
} from '@/types'

type Account = Profile & { password: string }
interface Review { id: string; order_id: string; vendor_id: string; product_id?: string; user_id: string; rating: number; comment: string | null; created_at: string }

let seq = 0
const uid = (p: string) => `${p}-${++seq}`
const now = () => new Date(Date.UTC(2026, 10, 18, 2, 0, seq)).toISOString()

const person = (p: Partial<Account> & Pick<Account, 'id' | 'email' | 'full_name'>): Account => ({
  phone_number: '+639171234567', role: 'user', account_status: 'active', vendor_status: null, business_name: null, business_category: null,
  business_description: null, business_logo_url: null, avatar_url: null, campus_location_id: null, created_at: '2026-10-08T08:00:00Z',
  email_verified_at: '2026-10-08T08:00:00Z', terms_accepted_at: '2026-10-08T08:00:00Z', password: 'AeroDrop#2026', ...p,
})

export function seed() {
  const locations: CampusLocation[] = [
    { id: 'main', name: 'UCLM Main Building', location_code: 'MAIN', latitude: 10.32521, longitude: 123.953201 },
    { id: 'annex2', name: 'UCLM Annex 2', location_code: 'ANNEX-2', latitude: 10.325633, longitude: 123.95377 },
    { id: 'maritime', name: 'UCLM Maritime Building', location_code: 'MARITIME', latitude: 10.326184, longitude: 123.954843 },
    { id: 'hub', name: 'Campus Base Hub', location_code: 'BASE-HUB', latitude: 10.325152, longitude: 123.953046 },
  ]
  const users: Account[] = [
    person({ id: 'maria', email: 'maria.santos@uclm.edu.ph', full_name: 'Maria Santos', campus_location_id: 'maritime' }),
    person({ id: 'kape', email: 'kapekanto@uclm.edu.ph', full_name: 'Jose Ramirez', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', business_category: 'Cafe', business_description: 'Brewed coffee, iced lattes and pastries by the Main Building lobby.', campus_location_id: 'main' }),
    person({ id: 'tea', email: 'teahaus@uclm.edu.ph', full_name: 'Liza Uy', role: 'vendor', vendor_status: 'pending', business_name: 'Tea Haus', business_category: 'Milk Tea', business_description: 'Milk tea and fruit tea with less-sugar options.', campus_location_id: 'annex2' }),
    person({ id: 'admin', email: 'admin@aerodrop.ph', full_name: 'AeroDrop Admin', role: 'admin' }),
  ]
  const product = (id: string, vendor_id: string, name: string, price: number, weight_grams: number, stock_quantity: number, category: string): Product => ({
    id, vendor_id, name, description: null, price, stock_quantity, category, weight_grams, image_url: null, is_active: true, created_at: '2026-10-09T08:00:00Z', rating: null, review_count: 0,
  })
  const products: Product[] = [
    product('latte', 'kape', 'Iced Spanish Latte', 120, 380, 24, 'Coffee'),
    product('americano', 'kape', 'Americano', 85, 350, 30, 'Coffee'),
    product('croissant', 'kape', 'Butter Croissant', 65, 90, 12, 'Pastry'),
  ]
  const drones: Drone[] = [
    { id: 'drn1', drone_code: 'DRN-001', drone_name: 'AeroCarrier Alpha', model: 'Prototype 001', max_payload_kg: 0.5, battery_level: 96, status: 'available', updated_at: '2026-11-18T01:00:00Z' },
  ]
  const weather: Weather = {
    safety_status: 'safe', condition: 'Partly cloudy', message: 'Conditions are within drone operating limits.', temperature: 30.4, wind_speed: 9.2, wind_gusts: 16.8,
    precipitation: 0, visibility: 24000, real_safety_status: 'safe', real_condition: 'Partly cloudy', override_status: null, override_until: null, updated_at: '2026-11-18T01:00:00Z',
  }
  return {
    session: null as string | null,
    locations, users, products, drones, weather,
    orders: [] as (Omit<Order, 'delivery' | 'vendor_name' | 'customer_name' | 'unread_messages'>)[],
    deliveries: [] as Delivery[],
    logs: [] as StatusLog[],
    telemetry: [] as (TelemetryInput & { recorded_at: string; drone_id: string | null })[],
    notifications: [] as AppNotification[],
    messages: [] as OrderMessage[],
    reports: [] as SupportReport[],
    supportMessages: [] as SupportMessage[],
    reviews: [] as Review[],
    zones: [] as NoFlyZone[],
    listeners: new Set<() => void>(),
  }
}

export type Db = ReturnType<typeof seed>
export const db: { current: Db } = { current: seed() }

const fail = (m: string): never => { throw new Error(m) }
const strip = ({ password: _p, ...p }: Account): Profile => p
const notify = (d: Db, user_id: string, title: string, message: string, notification_type: string, metadata: Record<string, unknown> = {}) =>
  d.notifications.unshift({ id: uid('n'), user_id, title, message, notification_type, is_read: false, created_at: now(), metadata })
const log = (d: Db, delivery_id: string, status: string, message: string) =>
  d.logs.unshift({ id: uid('log'), delivery_id, status, message, created_at: now() } as StatusLog)

function me(d: Db): Account {
  const u = d.users.find((x) => x.id === d.session)
  return u ?? fail('Not authenticated')
}
function hydrate(d: Db, o: Db['orders'][number]): Order {
  const viewer = d.session
  return {
    ...o,
    delivery: d.deliveries.find((x) => x.order_id === o.id) ?? null,
    vendor_name: d.users.find((u) => u.id === o.vendor_id)?.business_name ?? null,
    customer_name: d.users.find((u) => u.id === o.user_id)?.full_name ?? null,
    unread_messages: d.messages.filter((m) => m.order_id === o.id && m.sender_id !== viewer && !m.read_at).length,
  }
}
const visibleOrders = (d: Db) => {
  const v = me(d)
  return d.orders.filter((o) => v.role === 'admin' || (v.role === 'vendor' ? o.vendor_id === v.id : o.user_id === v.id))
}
const locName = (d: Db, id: string | null) => d.locations.find((l) => l.id === id)?.name ?? null
// The row's own coordinates, as the live simDeliveries returns them
const locCoords = (d: Db, id: string | null): [number, number] | null => {
  const l = d.locations.find((x) => x.id === id)
  return l ? [l.latitude, l.longitude] : null
}

const impl: Partial<Api> = {
  // ---------- Auth
  async currentUserId() { return db.current.session },
  onAuthChange(cb) { db.current.listeners.add(cb); return () => db.current.listeners.delete(cb) },
  async signIn(email, password) {
    const d = db.current
    const u = d.users.find((x) => x.email === email.trim().toLowerCase())
    if (!u || u.password !== password) fail('Invalid email or password.')
    if (u!.account_status === 'suspended') fail('Your account has been suspended. Please contact the administrator.')
    if (u!.role === 'vendor' && u!.vendor_status === 'rejected') fail('Your vendor application was rejected. Please contact the administrator.')
    d.session = u!.id
    return strip(u!)
  },
  async signOut() { db.current.session = null },
  async profile(id) { const u = db.current.users.find((x) => x.id === id); return u ? strip(u) : null },
  async accountStatus(id) { return db.current.users.find((x) => x.id === id)?.account_status ?? null },
  async updateProfile(id, patch) { Object.assign(db.current.users.find((x) => x.id === id)!, patch) },

  // ---------- Catalog
  async locations() { return db.current.locations },
  async weather() { return db.current.weather },
  async hubCoords() { const h = db.current.locations.find((l) => l.location_code === 'BASE-HUB')!; return [h.latitude, h.longitude] },
  async deliveryZone() { return null },
  async vendors() {
    const d = db.current
    return d.users.filter((u) => u.role === 'vendor' && u.vendor_status === 'active' && u.account_status === 'active').map((u) => {
      const rs = d.reviews.filter((r) => r.vendor_id === u.id && !r.product_id)
      return { ...strip(u), rating: rs.length ? rs.reduce((s, r) => s + r.rating, 0) / rs.length : null, review_count: rs.length }
    })
  },
  async products(opts) {
    const d = db.current
    const active = new Set(d.users.filter((u) => u.role === 'vendor' && u.vendor_status === 'active').map((u) => u.id))
    return d.products.filter((p) => (opts?.vendorId ? p.vendor_id === opts.vendorId : active.has(p.vendor_id)) && (opts?.includeInactive || p.is_active))
  },
  async product(id) { return db.current.products.find((p) => p.id === id) ?? null },
  async vendorReviews(vendorId) {
    const d = db.current
    return d.reviews.filter((r) => r.vendor_id === vendorId && !r.product_id).map((r) => ({ id: r.id, rating: r.rating, comment: r.comment, reviewer_name: d.users.find((u) => u.id === r.user_id)?.full_name ?? null, created_at: r.created_at }))
  },
  async productReviews(productId) {
    const d = db.current
    return d.reviews.filter((r) => r.product_id === productId).map((r) => ({ id: r.id, rating: r.rating, comment: r.comment, reviewer_name: d.users.find((u) => u.id === r.user_id)?.full_name ?? null, created_at: r.created_at }))
  },

  // ---------- Orders
  async orders() { const d = db.current; return visibleOrders(d).map((o) => hydrate(d, o)) },
  async order(id) { const d = db.current; const o = visibleOrders(d).find((x) => x.id === id); return o ? hydrate(d, o) : null },
  async quoteOrderFee(input) {
    const d = db.current
    const lines = input.items.map((i) => ({ p: d.products.find((p) => p.id === i.product_id)!, q: i.quantity }))
    const subtotal = lines.reduce((s, l) => s + l.p.price * l.q, 0)
    const grams = lines.reduce((s, l) => s + l.p.weight_grams * l.q, 0)
    const weight = Math.round(grams) / 100
    const deliveryFee = 15 + 8.39 + weight
    return { subtotal, deliveryFee, totalAmount: subtotal + deliveryFee, totalWeightGrams: grams, tripsRequired: Math.max(1, Math.ceil(grams / 500)), distanceKm: 0.2097, isCaution: false, breakdown: { base: 15, distance: 8.39, weight, extraTrip: 0, weather: 0 } }
  },
  async placeOrder(input: PlaceOrderInput) {
    const d = db.current
    const u = me(d)
    if (d.weather.safety_status === 'grounded') fail(`Ordering blocked: ${d.weather.message}`)
    if (!u.email_verified_at) fail('Verify your email before placing an order.')
    for (const i of input.items) {
      const p = d.products.find((x) => x.id === i.product_id) ?? fail(`Product not found: ${i.product_id}`)
      if (p.stock_quantity < i.quantity) fail(`Not enough stock available for ${p.name}. Only ${p.stock_quantity} item(s) remaining.`)
    }
    const id = uid('ord')
    const items = input.items.map((i) => {
      const p = d.products.find((x) => x.id === i.product_id)!
      p.stock_quantity -= i.quantity
      return { id: uid('item'), product_id: p.id, product_name: p.name, quantity: i.quantity, unit_price: p.price, subtotal: p.price * i.quantity, weight_grams: p.weight_grams }
    })
    const t = now()
    d.orders.unshift({
      id, user_id: u.id, vendor_id: input.vendorId, delivery_location_id: input.dropoffLocationId, order_status: 'pending', payment_status: 'paid', payment_method: input.paymentMethod,
      paid_at: t, subtotal: input.subtotal, delivery_fee: input.deliveryFee, total_amount: input.totalAmount, notes: input.notes ?? null, cancellation_reason: null, created_at: t, updated_at: t, items,
    })
    notify(d, input.vendorId, 'New Order Received', `${u.full_name} placed a new order.`, 'new_order', { order_id: id })
    return id
  },
  async cancelOrder(id) { const o = db.current.orders.find((x) => x.id === id)!; o.order_status = 'cancelled'; o.cancellation_reason = 'customer'; o.payment_status = 'refunded' },
  async setOrderStatus(id, status) {
    const d = db.current
    const o = d.orders.find((x) => x.id === id)!
    o.order_status = status
    if (status === 'confirmed') notify(d, o.user_id!, 'Order Confirmed', 'The vendor has accepted your order.', 'order_confirmed', { order_id: id })
    if (status === 'preparing') notify(d, o.user_id!, 'Preparing Your Order', 'The vendor is preparing your order.', 'order_preparing', { order_id: id })
    if (status === 'rejected' || status === 'cancelled') { o.cancellation_reason = 'vendor'; o.payment_status = 'refunded' }
  },
  async markOrderReady(id) {
    const d = db.current
    const v = me(d)
    if (v.role !== 'vendor' || v.vendor_status !== 'active') fail('Unauthorized: Caller is not an active approved vendor')
    const o = d.orders.find((x) => x.id === id) ?? fail('Order not found')
    if (o.vendor_id !== v.id) fail('Unauthorized: Order belongs to another vendor')
    if (!['confirmed', 'preparing', 'ready_for_delivery'].includes(o.order_status)) fail('Invalid order status: Must be confirmed, preparing, or ready_for_delivery')
    if (d.weather.safety_status === 'grounded') fail('Flight dispatch blocked: Weather is grounded')
    const grams = o.items.reduce((s, i) => s + i.weight_grams * i.quantity, 0)
    const trips = Math.max(1, Math.ceil(grams / 500))
    const drone = d.drones.find((x) => x.status === 'available')
    o.order_status = 'ready_for_delivery'
    const t = now()
    const dl: Delivery = {
      id: uid('dl'), order_id: id, drone_id: drone?.id ?? null, pickup_location_id: v.campus_location_id, dropoff_location_id: o.delivery_location_id,
      status: drone ? 'assigning' : 'pending', progress: 0, estimated_delivery_seconds: 720 * trips, delivery_started_at: null, delivery_completed_at: null, trips_required: trips, trips_completed: 0, created_at: t,
    }
    d.deliveries.unshift(dl)
    if (!drone) return 'Drone currently unavailable. This order is ready and waiting for the next available drone.'
    drone.status = 'assigned'
    log(d, dl.id, 'assigning', `${drone.drone_code} assigned and dispatched to vendor for package pickup.`)
    notify(d, o.user_id!, 'Drone Dispatched to Vendor', `${drone.drone_code} is on its way to the vendor to pick up your order.`, 'drone_dispatched', { order_id: id, delivery_id: dl.id })
    notify(d, v.id, 'Drone Heading to Pickup', `${drone.drone_code} has been dispatched to pick up the package from your shop.`, 'drone_dispatched', { order_id: id, delivery_id: dl.id })
    return `Order is ready for delivery. ${drone.drone_code} dispatched for pickup.`
  },
  async orderReviews(orderId) {
    const rs = db.current.reviews.filter((r) => r.order_id === orderId)
    const store = rs.find((r) => !r.product_id)
    return { store: store ? { rating: store.rating, comment: store.comment } : null, products: Object.fromEntries(rs.filter((r) => r.product_id).map((r) => [r.product_id!, { rating: r.rating, comment: r.comment }])) }
  },
  async submitReview(orderId, draft) {
    const d = db.current
    const u = me(d)
    const o = d.orders.find((x) => x.id === orderId)!
    if (o.order_status !== 'delivered') fail('Only delivered orders can be reviewed.')
    if (draft.storeRating) d.reviews.push({ id: uid('rv'), order_id: orderId, vendor_id: o.vendor_id!, user_id: u.id, rating: draft.storeRating, comment: draft.storeComment.trim() || null, created_at: now() })
    for (const p of draft.products) d.reviews.push({ id: uid('rv'), order_id: orderId, vendor_id: o.vendor_id!, product_id: p.product_id, user_id: u.id, rating: p.rating, comment: p.comment?.trim() || null, created_at: now() })
  },
  async telemetry(deliveryId) {
    const t = db.current.telemetry.find((x) => x.deliveryId === deliveryId)
    return t ? { latitude: t.latitude, longitude: t.longitude, altitude: t.altitude, speed: t.speed, battery_level: t.battery, recorded_at: t.recorded_at } : null
  },
  async fleetTelemetry() {
    const d = db.current
    return d.drones.flatMap((dr) => {
      const t = d.telemetry.find((x) => x.drone_id === dr.id)
      return t ? [{ drone_id: dr.id, latitude: t.latitude, longitude: t.longitude, altitude: t.altitude, speed: t.speed, battery_level: t.battery, recorded_at: t.recorded_at }] : []
    })
  },

  // ---------- Chat
  async messages(orderId) { return db.current.messages.filter((m) => m.order_id === orderId) },
  async chatCounterpart(orderId) {
    const d = db.current
    const o = d.orders.find((x) => x.id === orderId)
    if (!o) return null
    const v = me(d)
    const other = d.users.find((u) => u.id === (v.id === o.user_id ? o.vendor_id : o.user_id))!
    return { id: other.id, name: other.role === 'vendor' ? other.business_name! : other.full_name, role: other.role === 'vendor' ? 'vendor' : 'customer', avatarUrl: null }
  },
  async sendMessage(orderId, text) {
    const d = db.current
    const o = d.orders.find((x) => x.id === orderId)!
    if (['delivered', 'cancelled', 'rejected'].includes(o.order_status)) fail('This chat is closed.')
    const v = me(d)
    d.messages.push({ id: uid('msg'), order_id: orderId, sender_id: v.id, message: text, created_at: now(), read_at: null })
    notify(d, v.id === o.user_id ? o.vendor_id! : o.user_id!, 'New Message', text, 'order_message', { order_id: orderId })
  },
  async markMessagesRead(orderId) { const d = db.current; for (const m of d.messages) if (m.order_id === orderId && m.sender_id !== d.session) m.read_at = now() },
  subscribeMessages() { return () => {} },

  // ---------- Notifications
  async notifications() { const d = db.current; return d.notifications.filter((n) => n.user_id === d.session) },
  async markNotificationRead(id) { db.current.notifications.find((n) => n.id === id)!.is_read = true },
  async markAllNotificationsRead() { const d = db.current; for (const n of d.notifications) if (n.user_id === d.session) n.is_read = true },

  // ---------- Support
  async submitReport(input) {
    const d = db.current
    const u = me(d)
    const id = uid('rep')
    d.reports.unshift({ id, user_id: u.id, subject: input.subject, message: input.message, category: input.category, status: 'open', admin_notes: null, order_id: input.orderId ?? null, delivery_id: input.deliveryId ?? null, created_at: now(), resolved_at: null, reporter_name: u.full_name })
    for (const a of d.users.filter((x) => x.role === 'admin')) notify(d, a.id, 'New Support Report', `${u.full_name}: ${input.subject}`, 'support_report', { report_id: id })
    return id
  },
  async reports() { const d = db.current; const v = me(d); return d.reports.filter((r) => v.role === 'admin' || r.user_id === v.id) },
  async report(id) { const d = db.current; const v = me(d); return d.reports.find((r) => r.id === id && (v.role === 'admin' || r.user_id === v.id)) ?? null },
  async supportMessages(reportId) { return db.current.supportMessages.filter((m) => m.report_id === reportId) },
  async sendSupportMessage(reportId, text) {
    const d = db.current
    const m: SupportMessage = { id: uid('sm'), report_id: reportId, sender_id: me(d).id, message: text, attachments: [], created_at: now(), read_at: null }
    d.supportMessages.push(m)
    return m
  },
  async markSupportRead() {},
  subscribeSupportMessages() { return () => {} },
  async supportUserName(userId) { return db.current.users.find((u) => u.id === userId)?.full_name ?? null },
  async updateReport(id, patch) {
    const d = db.current
    const r = d.reports.find((x) => x.id === id)!
    Object.assign(r, patch)
    if (patch.status === 'resolved') { r.resolved_at = now(); notify(d, r.user_id, 'Report Resolved', `Your report "${r.subject}" was resolved.`, 'support_resolved', { report_id: id }) }
  },

  // ---------- Vendor
  async saveProduct(input: ProductInput) {
    const d = db.current
    const v = me(d)
    if (input.id) { Object.assign(d.products.find((p) => p.id === input.id)!, input); return }
    d.products.push({ ...input, id: uid('prod'), vendor_id: v.id, created_at: now(), rating: null, review_count: 0 })
  },
  async deleteProduct(id) { const d = db.current; d.products = d.products.filter((p) => p.id !== id) },

  // ---------- Admin
  async users() { return db.current.users.map(strip) },
  async setAccountStatus(id, status) { db.current.users.find((u) => u.id === id)!.account_status = status },
  async setVendorStatus(id, status) {
    const d = db.current
    const u = d.users.find((x) => x.id === id)!
    u.vendor_status = status
    if (status === 'active') notify(d, id, 'Vendor Application Approved', 'Your store is now live on AeroDrop.', 'vendor_approved')
  },
  async drones() { return db.current.drones },
  async rechargeDrone(id) { Object.assign(db.current.drones.find((x) => x.id === id)!, { battery_level: 100, status: 'available' }) },
  async statusLogs(deliveryId) { const d = db.current; return deliveryId ? d.logs.filter((l) => l.delivery_id === deliveryId) : d.logs },
  async safetyChecks() { return null },
  async setWeatherOverride(state) { Object.assign(db.current.weather, { override_status: state, safety_status: state, message: state === 'grounded' ? 'Campus drone delivery is currently grounded due to unsafe weather.' : db.current.weather.message }) },
  async clearWeatherOverride() { Object.assign(db.current.weather, { override_status: null, safety_status: db.current.weather.real_safety_status, message: 'Conditions are within drone operating limits.' }) },
  async zones() { return db.current.zones },
  async saveZone(zone) { const d = db.current; if (zone.id) Object.assign(d.zones.find((z) => z.id === zone.id)!, zone); else d.zones.push({ ...zone, id: uid('zone') } as NoFlyZone) },
  async deleteZone(id) { const d = db.current; d.zones = d.zones.filter((z) => z.id !== id) },

  // ---------- Drone flight
  async simDeliveries() {
    const d = db.current
    const v = me(d)
    return d.deliveries.filter((dl) => {
      const o = d.orders.find((x) => x.id === dl.order_id)!
      return v.role === 'admin' || (v.role === 'vendor' ? o.vendor_id === v.id : o.user_id === v.id)
    }).map((dl): SimDelivery => {
      const o = d.orders.find((x) => x.id === dl.order_id)!
      return {
        id: dl.id, order_id: dl.order_id, status: dl.status, progress: dl.progress, drone_id: dl.drone_id, trips_required: dl.trips_required, trips_completed: dl.trips_completed,
        pickup_name: locName(d, dl.pickup_location_id), dropoff_name: locName(d, dl.dropoff_location_id),
        pickup_coords: locCoords(d, dl.pickup_location_id), dropoff_coords: locCoords(d, dl.dropoff_location_id),
        payload_kg: o.items.reduce((s, i) => s + i.weight_grams * i.quantity, 0) / 1000, delivered_at: dl.delivery_completed_at, created_at: dl.created_at,
      }
    })
  },
  async recordTelemetry(t) {
    const d = db.current
    const dl = d.deliveries.find((x) => x.id === t.deliveryId)!
    d.telemetry.unshift({ ...t, recorded_at: now(), drone_id: dl.drone_id })
    if (t.progress != null) dl.progress = t.progress
  },
  async setDroneBattery(id, battery) { db.current.drones.find((x) => x.id === id)!.battery_level = battery },
  async setDroneStatus(id, status) { db.current.drones.find((x) => x.id === id)!.status = status },
  async confirmPickup(deliveryId) {
    const d = db.current
    const dl = d.deliveries.find((x) => x.id === deliveryId)!
    const o = d.orders.find((x) => x.id === dl.order_id)!
    Object.assign(dl, { status: 'in_transit', progress: 0, delivery_started_at: now() })
    o.order_status = 'in_transit'
    d.drones.find((x) => x.id === dl.drone_id)!.status = 'busy'
    log(d, dl.id, 'in_transit', 'Package picked up. Drone is flying to the drop-off point.')
    notify(d, o.user_id!, 'Package Picked Up', 'The drone has picked up your order and is on its way.', 'package_picked_up', { order_id: o.id, delivery_id: dl.id })
  },
  async completeDelivery(deliveryId) {
    const d = db.current
    const dl = d.deliveries.find((x) => x.id === deliveryId)!
    const o = d.orders.find((x) => x.id === dl.order_id)!
    Object.assign(dl, { status: 'delivered', progress: 1, trips_completed: dl.trips_required, delivery_completed_at: now() })
    o.order_status = 'delivered'
    log(d, dl.id, 'delivered', `Package delivered to ${locName(d, dl.dropoff_location_id)}.`)
    notify(d, o.user_id!, 'Order Delivered', `Your package has arrived at ${locName(d, dl.dropoff_location_id)}.`, 'order_delivered', { order_id: o.id, delivery_id: dl.id })
    notify(d, o.vendor_id!, 'Order Delivered', `The order for ${d.users.find((u) => u.id === o.user_id)?.full_name} was delivered.`, 'order_delivered', { order_id: o.id, delivery_id: dl.id })
  },
  async arriveAtVendorForNextTrip() {},
  async completeDroneReturn(droneId) { db.current.drones.find((x) => x.id === droneId)!.status = 'available' },
  async claimSimLease() { return true },
  async lastFinishedDeliveryForDrone() { return null },
  async recoverStaleReturningDrone() { return false },
  subscribeChanges() { return () => {} },
}

/** The api object the pages import: the functions above as spies; anything else resolves to []. */
export const backendApi = new Proxy({} as Record<string, unknown>, {
  get(t, k: string) {
    if (!(k in t)) {
      const f = (impl as Record<string, unknown>)[k]
      t[k] = typeof f === 'function' ? vi.fn(f as (...a: unknown[]) => unknown) : vi.fn(async () => [])
    }
    return t[k]
  },
}) as unknown as Api

/** Starts a test with a fresh database, signed out. */
export function resetBackend() {
  seq = 0
  db.current = seed()
  try { sessionStorage.clear() } catch { /* ignore */ }
}

/** Signs a user in directly, as a returning session would be. */
export function signInAs(id: string) {
  db.current.session = id
  sessionStorage.setItem('aerodrop-unlocked', id)
}
