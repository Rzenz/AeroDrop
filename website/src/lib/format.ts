import type { DeliveryStatus, DroneStatus, Order, OrderStatus } from '@/types'

const peso = new Intl.NumberFormat('en-PH', { style: 'currency', currency: 'PHP' })
export const formatPeso = (n: number) => peso.format(n || 0)

export const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })

export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('en-PH', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })

export const formatTime = (iso: string) =>
  new Date(iso).toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' })

export function timeAgo(iso: string) {
  const s = Math.round((Date.now() - new Date(iso).getTime()) / 1000)
  if (s < 60) return 'just now'
  const m = Math.round(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.round(m / 60)
  if (h < 24) return `${h}h ago`
  const d = Math.round(h / 24)
  if (d < 7) return `${d}d ago`
  return formatDate(iso)
}

export const shortId = (id: string) => `#${id.replace(/-/g, '').slice(0, 8).toUpperCase()}`

export const initials = (name?: string | null) =>
  (name ?? '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join('') || '?'

export type Tone = 'neutral' | 'info' | 'success' | 'warning' | 'danger'

/**
 * Port of OrderModel.effectiveStatus: folds orders.order_status and
 * deliveries.status into the one status the customer sees.
 */
export function effectiveStatus(order: Pick<Order, 'order_status' | 'delivery'>): OrderStatus {
  const o = order.order_status
  const d = order.delivery?.status
  if (o === 'cancelled' || o === 'rejected' || d === 'cancelled') return o === 'rejected' ? 'rejected' : 'cancelled'
  if (o === 'delivered' || d === 'delivered') return 'delivered'
  if (o === 'pending' || o === 'confirmed' || o === 'preparing') return o
  if (d === 'in_transit' || o === 'in_transit') return 'in_transit'
  return o
}

export const orderStatusMeta: Record<OrderStatus, { label: string; tone: Tone }> = {
  pending: { label: 'Pending', tone: 'warning' },
  confirmed: { label: 'Confirmed', tone: 'info' },
  preparing: { label: 'Preparing', tone: 'info' },
  ready_for_delivery: { label: 'Ready for pickup', tone: 'info' },
  in_transit: { label: 'In transit', tone: 'info' },
  delivered: { label: 'Delivered', tone: 'success' },
  cancelled: { label: 'Cancelled', tone: 'neutral' },
  rejected: { label: 'Rejected', tone: 'danger' },
}

export const deliveryStatusMeta: Record<DeliveryStatus, { label: string; tone: Tone }> = {
  pending: { label: 'Pending', tone: 'warning' },
  assigning: { label: 'Heading to Pickup', tone: 'info' },
  in_transit: { label: 'In flight', tone: 'info' },
  delivered: { label: 'Delivered', tone: 'success' },
  cancelled: { label: 'Cancelled', tone: 'neutral' },
  failed: { label: 'Failed', tone: 'danger' },
}

export const droneStatusMeta: Record<DroneStatus, { label: string; tone: Tone }> = {
  available: { label: 'Available', tone: 'success' },
  assigned: { label: 'Assigned', tone: 'info' },
  busy: { label: 'In flight', tone: 'info' },
  returning: { label: 'Returning', tone: 'warning' },
  charging: { label: 'Charging', tone: 'warning' },
  maintenance: { label: 'Maintenance', tone: 'danger' },
  offline: { label: 'Offline', tone: 'neutral' },
}

export const paymentLabel = (m: string | null) =>
  m === 'xendit_online' ? 'Pay online (GCash or Card)' : m === 'gcash_simulated' ? 'Simulated GCash' : m === 'card_simulated' ? 'Simulated Card' : '—'
