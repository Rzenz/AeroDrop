// Demo campus for the screenshot harness. Same people, stores and products as
// the website's demo data (website/src/data/demo-seed.ts), as database rows.

import { createHash } from 'node:crypto'

let n = 0
// Deterministic but realistic-looking UUIDs (the app prints the first 8 hex
// characters as the delivery/order code, e.g. DEL-7F3A91C2).
const id = () => {
  const h = createHash('sha1').update(`aerodrop-demo-${++n}`).digest('hex')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`
}
// Pinned "now" so screenshots show a normal campus lunchtime; the capture
// script installs the same clock in the browser.
export const NOW = Number(process.env.MOCK_NOW ?? Date.now())
const ago = (ms) => new Date(NOW - ms).toISOString()
const MIN = 60_000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

export const ids = {}
const named = (k) => (ids[k] = id())

// Coordinates: the app's own offline fallbacks (location_provider.dart).
const campus_locations = [
  { id: named('main'), name: 'UCLM Main Building', location_code: 'MAIN', latitude: 10.32521, longitude: 123.953201 },
  { id: named('annex2'), name: 'UCLM Annex 2', location_code: 'ANNEX-2', latitude: 10.325633, longitude: 123.95377 },
  { id: named('basic'), name: 'UCLM Basic Education', location_code: 'BASIC-ED', latitude: 10.325133, longitude: 123.953853 },
  { id: named('maritime'), name: 'UCLM Maritime Building', location_code: 'MARITIME', latitude: 10.326184, longitude: 123.954843 },
  { id: named('hub'), name: 'Campus Base Hub', location_code: 'BASE-HUB', latitude: 10.325152, longitude: 123.953046 },
].map((l) => ({ ...l, created_at: ago(120 * DAY) }))

const person = (key, extra) => ({
  id: named(key), phone_number: '+639171234567', role: 'user', account_status: 'active', vendor_status: null,
  business_name: null, business_category: null, business_description: null, business_logo_url: null, avatar_url: null,
  campus_location_id: null, created_at: ago(40 * DAY), updated_at: ago(DAY), ...extra,
})

const users = [
  person('maria', { email: 'maria.santos@uclm.edu.ph', full_name: 'Maria Santos', campus_location_id: ids.maritime }),
  person('paolo', { email: 'paolo.reyes@uclm.edu.ph', full_name: 'Paolo Reyes' }),
  person('angel', { email: 'angel.cruz@uclm.edu.ph', full_name: 'Angel Cruz' }),
  person('joy', { email: 'joy.dizon@uclm.edu.ph', full_name: 'Joy Dizon' }),
  person('kape', { email: 'kapekanto@uclm.edu.ph', full_name: 'Jose Ramirez', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', business_category: 'Cafe', business_description: 'Brewed coffee, iced lattes and pastries by the Main Building lobby.', campus_location_id: ids.main, created_at: ago(60 * DAY) }),
  person('canteen', { email: 'canteen@uclm.edu.ph', full_name: 'Liza Fernandez', role: 'vendor', vendor_status: 'active', business_name: 'UCLM Canteen', business_category: 'School Canteen', business_description: 'Rice meals, siomai and merienda cooked fresh every morning.', campus_location_id: ids.annex2, created_at: ago(58 * DAY) }),
  person('tea', { email: 'teahaus@uclm.edu.ph', full_name: 'Carlo Tan', role: 'vendor', vendor_status: 'active', business_name: 'Tea Haus', business_category: 'Milk Tea', business_description: 'Milk tea and fruit tea with less-sugar options.', campus_location_id: ids.basic, created_at: ago(45 * DAY) }),
  person('mart', { email: 'campusmart@uclm.edu.ph', full_name: 'Rosa Lim', role: 'vendor', vendor_status: 'active', business_name: 'Campus Mart', business_category: 'Convenience Store', business_description: 'School supplies, snacks and drinks.', campus_location_id: ids.main, created_at: ago(50 * DAY) }),
  person('pan', { email: 'pandemandaue@uclm.edu.ph', full_name: 'Elena Bautista', role: 'vendor', vendor_status: 'pending', business_name: 'Pan de Mandaue', business_category: 'Bakery', business_description: 'Pandesal, ensaymada and ube cheese rolls baked on campus.', campus_location_id: ids.maritime, created_at: ago(DAY) }),
  person('admin', { email: 'admin.portal@uclm.edu', full_name: 'AeroDrop Admin', role: 'admin', phone_number: null, created_at: ago(90 * DAY) }),
]
// The vendor select embeds campus_locations(name) through campus_location_id.

const vendor_ratings_summary = [
  { vendor_id: ids.kape, average_rating: 4.7, review_count: 38 },
  { vendor_id: ids.canteen, average_rating: 4.4, review_count: 52 },
  { vendor_id: ids.tea, average_rating: 4.8, review_count: 41 },
  { vendor_id: ids.mart, average_rating: 4.2, review_count: 17 },
]

const P = (key, vendor, name, price, weight_grams, stock_quantity, category, description) => ({
  id: named(key), vendor_id: ids[vendor], name, price, weight_grams, stock_quantity, category, description,
  image_url: null, is_active: true, created_at: ago(n * HOUR), updated_at: ago(HOUR),
})
const products = [
  P('latte', 'kape', 'Iced Spanish Latte', 120, 380, 24, 'Coffee', 'Double shot over milk and condensed milk, 16 oz.'),
  P('americano', 'kape', 'Americano', 85, 350, 30, 'Coffee', 'Hot or iced, 12 oz.'),
  P('caramel', 'kape', 'Caramel Macchiato', 135, 380, 18, 'Coffee', 'Vanilla milk, espresso and caramel drizzle, 16 oz.'),
  P('croissant', 'kape', 'Butter Croissant', 65, 90, 12, 'Pastry', 'Baked every morning.'),
  P('cookie', 'kape', 'Chocolate Chip Cookie', 45, 60, 3, 'Pastry', 'Chewy, with dark chocolate chunks.'),
  P('adobo', 'canteen', 'Chicken Adobo Rice', 95, 420, 20, 'Rice Meal', 'Chicken adobo with garlic rice.'),
  P('siomai', 'canteen', 'Siomai Rice', 70, 300, 25, 'Rice Meal', 'Four pork siomai with chili garlic.'),
  P('pancit', 'canteen', 'Pancit Canton', 60, 280, 15, 'Noodles', 'Stir-fried noodles with vegetables.'),
  P('turon', 'canteen', 'Turon (2 pcs)', 30, 120, 40, 'Merienda', 'Banana and jackfruit spring rolls.'),
  P('classic', 'tea', 'Classic Milk Tea', 89, 450, 30, 'Milk Tea', 'Black tea, fresh milk and tapioca pearls, 22 oz.'),
  P('winter', 'tea', 'Wintermelon Milk Tea', 99, 450, 26, 'Milk Tea', 'Wintermelon syrup and pearls, 22 oz.'),
  P('mango', 'tea', 'Mango Fruit Tea', 95, 450, 0, 'Fruit Tea', 'Green tea with mango and nata, 22 oz.'),
  P('pad', 'mart', 'Yellow Pad (80 leaves)', 35, 180, 60, 'School Supplies', 'Intermediate pad paper.'),
  P('water', 'mart', 'Bottled Water 500 ml', 20, 480, 80, 'Drinks', 'Chilled.'),
  P('pen', 'mart', 'Black Gel Pen (3 pcs)', 45, 40, 50, 'School Supplies', '0.5 mm.'),
  P('chips', 'mart', 'Potato Chips', 38, 60, 35, 'Snacks', 'Sour cream flavour, 60 g.'),
]
const product_ratings_summary = products.map((p, i) => ({ product_id: p.id, average_rating: 4 + ((i * 7) % 10) / 10, review_count: (i * 5) % 23 }))
const prod = (key) => products.find((p) => p.id === ids[key])

const drones = [
  { id: named('drn1'), drone_code: 'DRN-001', drone_name: 'AeroCarrier Alpha', model: 'Prototype 001', max_payload_kg: 0.5, battery_level: 86, status: 'busy', created_at: ago(90 * DAY), updated_at: ago(MIN) },
  { id: named('drn2'), drone_code: 'DRN-002', drone_name: 'AeroCarrier Beta', model: 'Prototype 001', max_payload_kg: 0.5, battery_level: 41, status: 'charging', created_at: ago(80 * DAY), updated_at: ago(30 * MIN) },
  { id: named('drn3'), drone_code: 'DRN-003', drone_name: 'AeroCarrier Gamma', model: 'Prototype 002', max_payload_kg: 0.5, battery_level: 100, status: 'maintenance', created_at: ago(70 * DAY), updated_at: ago(3 * DAY) },
]

const orders = []
const order_items = []
const deliveries = []

function order(key, { user, vendor, items, status, age, dropoff = 'maritime', method = 'gcash_simulated', delivery }) {
  const oid = named(key)
  let subtotal = 0
  for (const [pk, q] of items) {
    const p = prod(pk)
    subtotal += p.price * q
    order_items.push({ id: id(), order_id: oid, product_id: p.id, product_name: p.name, quantity: q, unit_price: p.price, subtotal: p.price * q, weight_grams: p.weight_grams })
  }
  const fee = 23.19
  orders.push({
    id: oid, user_id: ids[user], vendor_id: ids[vendor], delivery_location_id: ids[dropoff], order_status: status,
    payment_status: status === 'cancelled' ? 'refunded' : 'paid', payment_method: method, payment_reference: null,
    subtotal, delivery_fee: fee, total_amount: subtotal + fee, notes: null, cancellation_reason: status === 'cancelled' ? 'customer' : null,
    trips_required: 1, created_at: ago(age), updated_at: ago(age), paid_at: ago(age),
  })
  if (delivery) {
    const v = users.find((u) => u.id === ids[vendor])
    deliveries.push({
      id: named(`${key}-dl`), order_id: oid, drone_id: ids.drn1, pickup_location_id: v.campus_location_id, dropoff_location_id: ids[dropoff],
      progress: 0, estimated_delivery_seconds: 240, delivery_started_at: null, delivery_completed_at: null,
      trips_required: 1, trips_completed: 0, created_at: ago(age), updated_at: ago(MIN), ...delivery,
    })
  }
}

// Maria: one in the air, one being prepared, history.
order('live', { user: 'maria', vendor: 'kape', items: [['latte', 1]], status: 'in_transit', age: 14 * MIN, delivery: { status: 'in_transit', progress: 0.45, delivery_started_at: ago(110_000) } })
order('prep', { user: 'maria', vendor: 'tea', items: [['classic', 1]], status: 'preparing', age: 6 * MIN })
order('h1', { user: 'maria', vendor: 'canteen', items: [['adobo', 1], ['turon', 1]], status: 'delivered', age: 3 * HOUR, delivery: { status: 'delivered', progress: 1, delivery_started_at: ago(3 * HOUR - 12 * MIN), delivery_completed_at: ago(3 * HOUR - 17 * MIN), trips_completed: 1 } })
order('h2', { user: 'maria', vendor: 'mart', items: [['pad', 2], ['pen', 1]], status: 'delivered', age: DAY + 2 * HOUR, delivery: { status: 'delivered', progress: 1, delivery_started_at: ago(DAY), delivery_completed_at: ago(DAY - 5 * MIN), trips_completed: 1 } })
order('h3', { user: 'maria', vendor: 'kape', items: [['croissant', 2]], status: 'cancelled', age: 3 * DAY })
// Other customers, for the vendor and admin views.
order('o1', { user: 'paolo', vendor: 'kape', items: [['americano', 1], ['cookie', 1]], status: 'pending', age: 4 * MIN, dropoff: 'annex2' })
order('o2', { user: 'angel', vendor: 'kape', items: [['caramel', 1]], status: 'confirmed', age: 9 * MIN, dropoff: 'basic' })
order('o3', { user: 'joy', vendor: 'kape', items: [['latte', 2]], status: 'delivered', age: 5 * HOUR, dropoff: 'main', delivery: { status: 'delivered', progress: 1, delivery_started_at: ago(5 * HOUR - 10 * MIN), delivery_completed_at: ago(5 * HOUR - 14 * MIN), trips_completed: 1 } })
// A week of Kape Kanto sales so the vendor's 7-day chart reads like a real café.
const week = [
  [1, 'paolo', [['latte', 1], ['croissant', 1]]],
  [1, 'angel', [['americano', 2]]],
  [2, 'joy', [['caramel', 1]]],
  [3, 'paolo', [['latte', 2], ['cookie', 1]]],
  [3, 'maria', [['americano', 1]]],
  [4, 'angel', [['latte', 1]]],
  [5, 'joy', [['caramel', 2], ['croissant', 1]]],
  [5, 'paolo', [['americano', 1], ['cookie', 2]]],
  [6, 'angel', [['latte', 1], ['croissant', 2]]],
]
week.forEach(([d, user, items], i) => {
  const age = d * DAY + (i % 3) * HOUR
  order(`w${i}`, { user, vendor: 'kape', items, status: 'delivered', age, dropoff: ['main', 'annex2', 'basic', 'maritime'][i % 4], delivery: { status: 'delivered', progress: 1, delivery_started_at: ago(age - 9 * MIN), delivery_completed_at: ago(age - 13 * MIN), trips_completed: 1 } })
})

// Telemetry for the live flight; the app's simulator appends to it as it flies.
const drone_telemetry = [
  { id: id(), delivery_id: ids['live-dl'], drone_id: ids.drn1, latitude: 10.3252, longitude: 123.9534, altitude: 30, speed: 6.2, battery_level: 86, signal_strength: 98, heading: 90, event_type: 'traveling_to_dropoff', recorded_at: ago(5000) },
]

const weather_safety = [{
  id: id(), safety_status: 'safe', condition: 'Partly cloudy', message: 'Conditions are within drone operating limits.',
  temperature: 30.4, wind_speed: 9.2, wind_gusts: 16.8, precipitation: 0, weather_code: 2, visibility: 24000,
  real_safety_status: 'safe', real_condition: 'Partly cloudy', real_message: 'Conditions are within drone operating limits.',
  override_status: null, override_until: null, override_by: null, last_fetched_at: ago(7 * MIN), last_fetch_error: null, updated_at: ago(7 * MIN),
}]

const N = (user, title, message, notification_type, age, is_read, metadata = {}) => ({ id: id(), user_id: ids[user], title, message, notification_type, is_read, read_at: is_read ? ago(age - MIN) : null, related_delivery_id: null, metadata, created_at: ago(age) })
const notifications = [
  N('maria', 'Drone dispatched', 'Your order from Kape Kanto is on its way.', 'drone_dispatched', 2 * MIN, false, { order_id: ids.live }),
  N('maria', 'Order is being prepared', 'Tea Haus is preparing your Classic Milk Tea.', 'order_preparing', 5 * MIN, false, { order_id: ids.prep }),
  N('maria', 'Order delivered', 'Your package has arrived at UCLM Maritime Building.', 'order_delivered', 3 * HOUR - 17 * MIN, true, { order_id: ids.h1 }),
  N('maria', 'Payment confirmed', 'We received your GCash payment of ₱171.19.', 'payment_confirmed', 3 * HOUR, true, { order_id: ids.h1 }),
  N('kape', 'New order', 'Paolo Reyes placed an order for 2 items.', 'new_order', 4 * MIN, false, { order_id: ids.o1 }),
  N('admin', 'Vendor application', 'Pan de Mandaue applied to sell on AeroDrop.', 'vendor_application', DAY, false, { user_id: ids.pan }),
]

const M = (from, message, age, read = true) => ({ id: id(), order_id: ids.live, sender_id: ids[from], message, created_at: ago(age), read_at: read ? ago(age - 30_000) : null })
const order_messages = [
  M('maria', 'Hi! Can I get it with less ice?', 13 * MIN),
  M('kape', 'Sure! Less ice, same sweetness?', 12 * MIN),
  M('maria', 'Yes please. Thank you!', 11 * MIN),
  M('kape', 'Done. Marking it ready for the drone now.', 6 * MIN),
  M('maria', 'I’m at the Maritime Building lobby 👋', 4 * MIN),
  M('kape', 'Noted! It’s in the air, about 2 minutes away.', 2 * MIN, false),
]

const store_reviews = [
  { id: id(), vendor_id: ids.kape, rating: 5, comment: 'Arrived cold and fast. The drone landing was fun to watch.', reviewer_name: 'Maria S.', created_at: ago(2 * DAY) },
  { id: id(), vendor_id: ids.kape, rating: 4, comment: 'Packed well, nothing spilled.', reviewer_name: 'Paolo R.', created_at: ago(4 * DAY) },
]

export const db = {
  campus_locations, users, vendor_ratings_summary, products, product_ratings_summary, drones, orders, order_items,
  deliveries, drone_telemetry, weather_safety, notifications, order_messages, store_reviews,
  no_fly_zones: [], delivery_status_logs: [], support_reports: [], support_messages: [],
}
