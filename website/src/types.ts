// Row shapes mirror the Supabase tables the app uses (supabase/migrations).

export type Role = 'user' | 'vendor' | 'admin'
export type AccountStatus = 'active' | 'suspended' | 'deleted'
export type VendorStatus = 'pending' | 'active' | 'suspended' | 'rejected'

export interface Profile {
  id: string
  email: string
  full_name: string
  phone_number: string | null
  role: Role
  account_status: AccountStatus
  vendor_status: VendorStatus | null
  business_name: string | null
  business_category: string | null
  business_description: string | null
  business_logo_url: string | null
  avatar_url: string | null
  campus_location_id: string | null
  created_at: string
}

export interface Vendor extends Profile {
  rating: number | null
  review_count: number
}

export interface CampusLocation {
  id: string
  name: string
  location_code: string
  latitude: number
  longitude: number
}

export interface Product {
  id: string
  vendor_id: string
  name: string
  description: string | null
  price: number
  stock_quantity: number
  category: string | null
  weight_grams: number
  image_url: string | null
  is_active: boolean
  created_at: string
  rating?: number | null
  review_count?: number
}

export type OrderStatus =
  | 'pending'
  | 'confirmed'
  | 'preparing'
  | 'ready_for_delivery'
  | 'in_transit'
  | 'delivered'
  | 'cancelled'
  | 'rejected'

// Values place_order accepts (migration 16): online checkout is 'xendit_online'.
export type PaymentMethod = 'gcash_simulated' | 'card_simulated' | 'xendit_online'

export interface OrderItem {
  id: string
  product_id: string | null
  product_name: string
  quantity: number
  unit_price: number
  subtotal: number
  weight_grams: number
}

export type DeliveryStatus = 'pending' | 'assigning' | 'in_transit' | 'delivered' | 'cancelled' | 'failed'

export interface Delivery {
  id: string
  order_id: string
  drone_id: string | null
  pickup_location_id: string | null
  dropoff_location_id: string | null
  status: DeliveryStatus
  progress: number
  estimated_delivery_seconds: number | null
  delivery_started_at: string | null
  delivery_completed_at: string | null
  trips_required: number
  trips_completed: number
  created_at: string
}

export interface Order {
  id: string
  user_id: string | null
  vendor_id: string | null
  delivery_location_id: string | null
  order_status: OrderStatus
  payment_status: 'pending' | 'paid' | 'refunded' | 'failed' | 'expired'
  payment_method: PaymentMethod | null
  payment_invoice_url?: string | null
  paid_at?: string | null
  subtotal: number
  delivery_fee: number
  total_amount: number
  notes: string | null
  cancellation_reason: string | null
  created_at: string
  updated_at: string
  items: OrderItem[]
  delivery: Delivery | null
  vendor_name: string | null
  customer_name: string | null
  unread_messages: number
}

export type DroneStatus = 'available' | 'assigned' | 'busy' | 'returning' | 'charging' | 'maintenance' | 'offline'

export interface Drone {
  id: string
  drone_code: string
  drone_name: string | null
  model: string | null
  max_payload_kg: number
  battery_level: number
  status: DroneStatus
  updated_at: string
  latitude?: number | null
  longitude?: number | null
}

export interface AppNotification {
  id: string
  user_id: string
  title: string
  message: string
  notification_type: string | null
  is_read: boolean
  created_at: string
  metadata: Record<string, unknown> | null
}

export type WeatherState = 'safe' | 'caution' | 'grounded'

export interface Weather {
  safety_status: WeatherState
  condition: string | null
  message: string | null
  temperature: number | null
  wind_speed: number | null
  wind_gusts: number | null
  precipitation: number | null
  visibility: number | null
  real_safety_status: WeatherState | null
  real_condition: string | null
  override_status: WeatherState | null
  override_until: string | null
  updated_at: string
}

export interface NoFlyZone {
  id: string
  name: string
  description: string | null
  latitude: number
  longitude: number
  radius_meters: number
  is_active: boolean
}

export interface SupportReport {
  id: string
  user_id: string
  subject: string
  message: string
  category: string
  status: 'open' | 'resolved'
  admin_notes: string | null
  order_id: string | null
  created_at: string
  resolved_at: string | null
  reporter_name?: string | null
}

export interface OrderMessage {
  id: string
  order_id: string
  sender_id: string
  message: string
  created_at: string
  read_at: string | null
}

export interface StatusLog {
  id: string
  delivery_id: string
  status: string
  message: string | null
  created_at: string
}

export interface CartItem {
  productId: string
  productName: string
  vendorId: string
  vendorName: string
  imageUrl: string | null
  unitPrice: number
  weightGrams: number
  quantity: number
  stock: number
}
