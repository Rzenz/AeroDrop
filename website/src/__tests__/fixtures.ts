// Sample records shaped like the AeroDrop database, for the website tests.
// Names, stores and prices are the same demo campus used for the screenshots.
import type { AppNotification, Delivery, Drone, Order, OrderItem, Product, SupportReport, Vendor, Weather } from '@/types'
import { profile } from './helpers'

export const NOW = '2026-11-17T04:00:00Z'

export const vendor = (id: string, business_name: string, business_category: string, rating: number, review_count: number, extra: Partial<Vendor> = {}): Vendor => ({
  ...profile({ id, role: 'vendor', vendor_status: 'active', business_name, business_category, email: `${id}@uclm.edu.ph` }),
  business_description: null, rating, review_count, ...extra,
})
export const vendors: Vendor[] = [
  vendor('kape', 'Kape Kanto', 'Cafe', 4.7, 38, { campus_location_id: 'main', business_description: 'Brewed coffee, iced lattes and pastries by the Main Building lobby.' }),
  vendor('canteen', 'UCLM Canteen', 'School Canteen', 4.4, 52, { business_description: 'Rice meals, siomai and merienda cooked fresh every morning.' }),
  vendor('tea', 'Tea Haus', 'Milk Tea', 4.8, 41, { business_description: 'Milk tea and fruit tea with less-sugar options.' }),
  vendor('mart', 'Campus Mart', 'Convenience Store', 4.2, 17, { business_description: 'School supplies, snacks and drinks.' }),
]

export const product = (id: string, vendor_id: string, name: string, price: number, weight_grams: number, stock_quantity: number, category: string): Product => ({
  id, vendor_id, name, description: null, price, stock_quantity, category, weight_grams, image_url: null, is_active: true, created_at: NOW, rating: 4.5, review_count: 10,
})
export const products: Product[] = [
  product('latte', 'kape', 'Iced Spanish Latte', 120, 380, 24, 'Coffee'),
  product('americano', 'kape', 'Americano', 85, 350, 30, 'Coffee'),
  product('croissant', 'kape', 'Butter Croissant', 65, 90, 12, 'Pastry'),
  product('classic', 'tea', 'Classic Milk Tea', 89, 450, 30, 'Milk Tea'),
  product('winter', 'tea', 'Wintermelon Milk Tea', 99, 450, 26, 'Milk Tea'),
  product('mango', 'tea', 'Mango Fruit Tea', 95, 450, 0, 'Fruit Tea'),
  product('adobo', 'canteen', 'Chicken Adobo Rice', 95, 420, 20, 'Rice Meal'),
  product('pad', 'mart', 'Yellow Pad (80 leaves)', 35, 180, 60, 'School Supplies'),
]

const item = (p: Product, quantity: number): OrderItem => ({ id: `${p.id}-item`, product_id: p.id, product_name: p.name, quantity, unit_price: p.price, subtotal: p.price * quantity, weight_grams: p.weight_grams })
export const delivery = (order_id: string, extra: Partial<Delivery> = {}): Delivery => ({
  id: `${order_id}-dl`, order_id, drone_id: 'drn1', pickup_location_id: 'main', dropoff_location_id: 'maritime', status: 'in_transit', progress: 0.45,
  estimated_delivery_seconds: 240, delivery_started_at: NOW, delivery_completed_at: null, trips_required: 1, trips_completed: 0, created_at: NOW, ...extra,
})
export const order = (id: string, vendor_id: string, vendor_name: string, lines: [string, number][], order_status: Order['order_status'], extra: Partial<Order> = {}): Order => {
  const items = lines.map(([pid, q]) => item(products.find((p) => p.id === pid)!, q))
  const subtotal = items.reduce((s, i) => s + i.subtotal, 0)
  return {
    id, user_id: 'maria', vendor_id, delivery_location_id: 'maritime', order_status, payment_status: order_status === 'cancelled' ? 'refunded' : 'paid', payment_method: 'gcash_simulated',
    subtotal, delivery_fee: 23.19, total_amount: subtotal + 23.19, notes: null, cancellation_reason: null, created_at: NOW, updated_at: NOW, paid_at: NOW,
    items, delivery: null, vendor_name, customer_name: 'Maria Santos', unread_messages: 0, ...extra,
  }
}
export const locations = [
  { id: 'main', name: 'UCLM Main Building', location_code: 'MAIN', latitude: 10.32521, longitude: 123.953201 },
  { id: 'annex2', name: 'UCLM Annex 2', location_code: 'ANNEX-2', latitude: 10.325633, longitude: 123.95377 },
  { id: 'maritime', name: 'UCLM Maritime Building', location_code: 'MARITIME', latitude: 10.326184, longitude: 123.954843 },
  { id: 'hub', name: 'Campus Base Hub', location_code: 'BASE-HUB', latitude: 10.325152, longitude: 123.953046 },
]
export const notification = (id: string, title: string, message: string, notification_type: string, is_read: boolean, metadata: Record<string, unknown> = {}): AppNotification => ({
  id, user_id: 'maria', title, message, notification_type, is_read, created_at: NOW, metadata,
})
export const drones: Drone[] = [
  { id: 'drn1', drone_code: 'DRN-001', drone_name: 'AeroCarrier Alpha', model: 'Prototype 001', max_payload_kg: 0.5, battery_level: 86, status: 'busy', updated_at: NOW },
  { id: 'drn2', drone_code: 'DRN-002', drone_name: 'AeroCarrier Beta', model: 'Prototype 001', max_payload_kg: 0.5, battery_level: 41, status: 'charging', updated_at: NOW },
]
export const weather: Weather = {
  safety_status: 'safe', condition: 'Partly cloudy', message: 'Conditions are within drone operating limits.', temperature: 30.4, wind_speed: 9.2, wind_gusts: 16.8,
  precipitation: 0, visibility: 24000, real_safety_status: 'safe', real_condition: 'Partly cloudy', override_status: null, override_until: null, updated_at: NOW,
}
export const report = (id: string, subject: string, status: SupportReport['status'], extra: Partial<SupportReport> = {}): SupportReport => ({
  id, user_id: 'maria', subject, message: 'The drone landed at Annex 2 instead of the Maritime Building.', category: 'delivery_issue', status, admin_notes: null,
  order_id: null, created_at: NOW, resolved_at: null, reporter_name: 'Maria Santos', ...extra,
})
