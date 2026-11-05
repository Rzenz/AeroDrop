import type { Coords } from '@/lib/flight-calc'
import type {
  AccountStatus,
  DroneStatus,
  AppNotification,
  CampusLocation,
  Drone,
  NoFlyZone,
  Order,
  OrderMessage,
  OrderStatus,
  PaymentMethod,
  Product,
  Profile,
  StatusLog,
  SupportReport,
  Vendor,
  VendorStatus,
  Weather,
  WeatherState,
} from '@/types'
import { liveApi } from './live-api'

export interface SignUpInput {
  fullName: string
  email: string
  password: string
  phone: string
  role: 'user' | 'vendor'
  businessName?: string
  businessCategory?: string
  businessDescription?: string
  campusLocationId?: string
}

export interface PlaceOrderInput {
  vendorId: string
  dropoffLocationId: string
  subtotal: number
  deliveryFee: number
  totalAmount: number
  paymentMethod: PaymentMethod
  notes?: string
  items: { product_id: string; product_name: string; quantity: number; unit_price: number }[]
}

export interface ProductInput {
  id?: string
  name: string
  description: string
  price: number
  stock_quantity: number
  category: string
  weight_grams: number
  image_url: string | null
  is_active: boolean
}

export interface Telemetry {
  latitude: number
  longitude: number
  altitude: number | null
  speed: number | null
  battery_level: number | null
  recorded_at: string
}

export interface Review {
  id: string
  rating: number
  comment: string | null
  reviewer_name: string | null
  created_at: string
}

/** A delivery as the flight simulator sees it (DeliveryNotifier._mapToDeliveryModel). */
export interface SimDelivery {
  id: string
  order_id: string
  status: 'pending' | 'assigning' | 'in_transit' | 'delivered' | 'cancelled' | 'failed'
  /** Progress of the current leg: leg 1 while assigning, leg 2 while in transit. */
  progress: number
  drone_id: string | null
  trips_required: number
  trips_completed: number
  pickup_name: string | null
  dropoff_name: string | null
  payload_kg: number
  delivered_at: string | null
  created_at: string
}

export interface TelemetryInput {
  deliveryId: string
  latitude: number
  longitude: number
  altitude: number
  speed: number
  battery: number
  signal: number
  heading: number
  event: 'standby' | 'traveling_to_pickup' | 'in_flight' | 'returning_to_base'
  /** null on the return leg, so the server doesn't record it as delivery progress. */
  progress: number | null
}

export interface ReviewDraft {
  storeRating: number | null
  storeComment: string
  products: { product_id: string; rating: number; comment?: string }[]
}

export interface ExistingReviews {
  store: { rating: number; comment: string | null } | null
  products: Record<string, { rating: number; comment: string | null }>
}

/** get_order_counterpart: who is on the other side of an order's chat. */
export interface ChatCounterpart {
  id: string
  name: string
  role: 'vendor' | 'customer'
  avatarUrl: string | null
}

export type ChangeScope = { userId: string; role: 'user' | 'vendor' | 'admin' }

/** Everything the website reads or writes, implemented on the app's Supabase project. */
export interface Api {
  // Auth
  currentUserId(): Promise<string | null>
  onAuthChange(cb: () => void): () => void
  signIn(email: string, password: string): Promise<Profile>
  sendLoginCode(email: string): Promise<void>
  verifyLoginCode(email: string, code: string): Promise<void>
  signUp(input: SignUpInput): Promise<void>
  verifySignUpCode(email: string, code: string): Promise<void>
  sendPasswordReset(email: string): Promise<void>
  resetPassword(email: string, code: string, newPassword: string): Promise<void>
  /** Re-checks the current password first, as change_password_page.dart does. */
  changePassword(currentPassword: string, newPassword: string): Promise<void>
  /** settings_page.dart: Supabase emails a confirmation link to the new address. */
  changeEmail(newEmail: string): Promise<void>
  resendSignUpCode(email: string): Promise<void>
  /** check_google_only_account: explains a failed password sign-in. */
  isGoogleOnlyAccount(email: string): Promise<boolean>
  /** Starts Google OAuth (customers, and approved vendors). Redirects away. */
  signInWithGoogle(): Promise<void>
  /** Finishes Google OAuth on /auth/callback with the app's role rules. */
  completeGoogleSignIn(): Promise<Profile>
  accountStatus(userId: string): Promise<AccountStatus | null>
  signOut(): Promise<void>
  profile(id: string): Promise<Profile | null>
  updateProfile(id: string, patch: Partial<Pick<Profile, 'full_name' | 'phone_number' | 'business_name' | 'business_description' | 'business_category' | 'campus_location_id' | 'avatar_url'>>): Promise<void>

  // Storage (the app's buckets and paths)
  uploadAvatar(file: File): Promise<string> // avatars/<uid>/avatar.<ext>
  /** vendor-logos/<uid>/logo.<ext> from the profile, business_logo.<ext> at sign-up (as in the app). */
  uploadStoreLogo(file: File, name?: 'logo' | 'business_logo'): Promise<string>
  removeStoreLogo(): Promise<void>
  uploadProductImage(file: File): Promise<string> // product-images/<uid>/prod_<ms>.<ext>

  // Catalog
  locations(): Promise<CampusLocation[]>
  weather(): Promise<Weather>
  vendors(): Promise<Vendor[]>
  products(opts?: { vendorId?: string; includeInactive?: boolean }): Promise<Product[]>
  product(id: string): Promise<Product | null>
  vendorReviews(vendorId: string): Promise<Review[]>
  /** get_product_reviews, as in the app's product reviews sheet. */
  productReviews(productId: string): Promise<Review[]>

  // Orders (scoped by role: customers see theirs, vendors their store's, admins all)
  orders(): Promise<Order[]>
  order(id: string): Promise<Order | null>
  placeOrder(input: PlaceOrderInput): Promise<string>
  startOnlinePayment(orderId: string): Promise<string>
  cancelOrder(id: string): Promise<void>
  orderReviews(orderId: string): Promise<ExistingReviews>
  submitReview(orderId: string, draft: ReviewDraft): Promise<void>
  telemetry(deliveryId: string): Promise<Telemetry | null>
  /** Latest telemetry per drone, for the admin radar. */
  fleetTelemetry(): Promise<(Telemetry & { drone_id: string })[]>

  // Chat
  messages(orderId: string): Promise<OrderMessage[]>
  /** The other party's display name and avatar, as the app's chat header shows them. */
  chatCounterpart(orderId: string): Promise<ChatCounterpart | null>
  sendMessage(orderId: string, text: string): Promise<void>
  markMessagesRead(orderId: string): Promise<void>
  subscribeMessages(orderId: string, cb: () => void): () => void

  // Notifications
  notifications(): Promise<AppNotification[]>
  markNotificationRead(id: string): Promise<void>
  markAllNotificationsRead(): Promise<void>

  // Support
  submitReport(input: { subject: string; message: string; category: string; orderId?: string; deliveryId?: string }): Promise<void>
  reports(): Promise<SupportReport[]>
  updateReport(id: string, patch: { status?: 'open' | 'resolved'; admin_notes?: string }): Promise<void>

  // Vendor
  saveProduct(input: ProductInput): Promise<void>
  deleteProduct(id: string): Promise<void>
  setOrderStatus(id: string, status: OrderStatus): Promise<void>
  markOrderReady(id: string): Promise<string>

  // Admin
  users(): Promise<Profile[]>
  setAccountStatus(id: string, status: AccountStatus): Promise<void>
  setVendorStatus(id: string, status: VendorStatus): Promise<void>
  deleteUser(id: string): Promise<void>
  drones(): Promise<Drone[]>
  /** DroneNotifier.rechargeDrone: battery 100, available. The app's only admin drone action. */
  rechargeDrone(id: string): Promise<void>
  statusLogs(deliveryId?: string): Promise<StatusLog[]>
  /** reports_page.dart reads delivery_safety_checks; null when the table isn't there. */
  safetyChecks(): Promise<Record<string, unknown>[] | null>
  setWeatherOverride(state: WeatherState): Promise<void>
  clearWeatherOverride(): Promise<void>
  zones(): Promise<NoFlyZone[]>
  saveZone(zone: Omit<NoFlyZone, 'id'> & { id?: string }): Promise<void>
  deleteZone(id: string): Promise<void>

  // Flight simulator (DeliveryNotifier._startSimulation). Same RPCs and writes
  // as the app, so a website tab can fly the drone when no phone is open.
  simDeliveries(): Promise<SimDelivery[]>
  hubCoords(): Promise<Coords>
  recordTelemetry(t: TelemetryInput): Promise<void>
  setDroneBattery(droneId: string, battery: number): Promise<void>
  setDroneStatus(droneId: string, status: DroneStatus): Promise<void>
  confirmPickup(deliveryId: string): Promise<void>
  completeDelivery(deliveryId: string): Promise<void>
  arriveAtVendorForNextTrip(deliveryId: string): Promise<void>
  completeDroneReturn(droneId: string): Promise<void>
  claimSimLease(droneId: string): Promise<boolean>
  lastFinishedDeliveryForDrone(droneId: string): Promise<string | null>
  recoverStaleReturningDrone(droneId: string): Promise<boolean>

  /** Realtime: calls back when rows this user can see change (live mode). */
  subscribeChanges(scope: ChangeScope, cb: () => void): () => void
}

export const api: Api = liveApi
