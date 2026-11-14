import { isAdminEmail, supabase } from '@/lib/config'
import type { Delivery, Order, OrderItem, Product, Profile, SupportMessage, SupportReport, Vendor, Weather } from '@/types'
import { SUPPORT_MAX_PHOTOS, SUPPORT_MESSAGE_MAX } from '@/lib/constants'
import { DEFAULT_HUB, type Coords } from '@/lib/flight-calc'
import type { Api, EmailCheck, SimDelivery, Telemetry } from './api'
import { authMessage, authOk, EmailNotVerifiedError, EmailRejectedError, isAlreadyRegistered, isRateLimited } from './auth-errors'

// Supabase implementation of Api. Every call mirrors what the Flutter app does
// (same tables, RPCs and edge function), so row level security behaves the
// same for the website as it does for the app.

const sb = () => supabase

type Res = { data: unknown; error: { message: string } | null }

/** Unwrap a PostgREST/Auth response, throwing its message. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function ok<T = any>(res: Res): T {
  if (res.error) throw new Error(res.error.message)
  return res.data as T
}

/** Same, for list queries: never null. */
const rows = <T,>(res: Res): T[] => ok<T[] | null>(res) ?? []

const nowIso = () => new Date().toISOString()

async function me(): Promise<Profile> {
  const { data } = await sb().auth.getUser()
  if (!data.user) throw new Error('Your session has ended. Please sign in again.')
  const row = ok(await sb().from('users').select('*').eq('id', data.user.id).maybeSingle())
  if (!row) throw new Error('Your account profile is not synchronized with the database.')
  return row as Profile
}

type OrderRow = Omit<Order, 'items' | 'delivery' | 'vendor_name' | 'customer_name' | 'unread_messages'> & {
  order_items: OrderItem[] | null
  deliveries: Delivery | Delivery[] | null
}

const ORDER_SELECT = '*, order_items(*), deliveries(*)'

// ImageUtils.validateImage: JPEG, PNG or WebP, under 5 MB.
const IMAGE_TYPES: Record<string, string> = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp' }
function checkImage(file: File) {
  const ext = IMAGE_TYPES[file.type]
  if (!ext) throw new Error('Choose a JPG, PNG or WebP image.')
  if (file.size > 5 * 1024 * 1024) throw new Error('Image is too large. Please choose an image under 5 MB.')
  return ext
}
async function upload(bucket: string, path: string, file: File) {
  ok(await sb().storage.from(bucket).upload(path, file, { contentType: file.type, upsert: true }))
  // Cache-bust so an overwritten avatar or logo shows the new image.
  return `${sb().storage.from(bucket).getPublicUrl(path).data.publicUrl}?v=${Date.now()}`
}
// ── Support threads (support_chat_provider.dart) ──────────────────────────
/** Private bucket; objects live at <report_id>/<uuid>.<ext> (the policy reads the folder as the report id). */
const SUPPORT_BUCKET = 'support-attachments'
const SUPPORT_COLUMNS = 'id, report_id, sender_id, message, attachments, created_at, read_at'
const SIGNED_URL_SECONDS = 60 * 60
const SIGNED_URL_REUSE_MS = 50 * 60 * 1000
const signedUrls = new Map<string, { url: Promise<string>; signedAt: number }>()

const toSupportMessage = (r: Record<string, unknown>): SupportMessage => ({
  id: String(r.id ?? ''),
  report_id: String(r.report_id ?? ''),
  sender_id: String(r.sender_id ?? ''),
  message: String(r.message ?? ''),
  attachments: Array.isArray(r.attachments) ? r.attachments.map(String).filter(Boolean) : [],
  created_at: String(r.created_at ?? nowIso()),
  read_at: (r.read_at as string | null) ?? null,
})

/** SupportReportModel.fromMap: last reply time and unread count from the embedded replies. */
function withThreadStats(row: Record<string, unknown>, viewerId: string): SupportReport {
  const { support_messages: replies, ...report } = row
  let last: string | null = null
  let unread = 0
  for (const m of (Array.isArray(replies) ? replies : []) as { created_at: string; sender_id: string; read_at: string | null }[]) {
    if (!last || m.created_at > last) last = m.created_at
    if (m.sender_id !== viewerId && !m.read_at) unread++
  }
  return { ...(report as unknown as SupportReport), last_message_at: last, unread_count: unread }
}
const lastActivity = (r: SupportReport) => (r.last_message_at && r.last_message_at > r.created_at ? r.last_message_at : r.created_at)

/**
 * AuthNotifier._recordTermsAcceptance: a new account usually has no session
 * until it is verified, so sign-up keeps the acceptance time in the auth
 * metadata and the first signed-in session copies it to the profile. Only the
 * first write lands; older accounts without it stay NULL. Never blocks sign-in.
 */
async function recordTermsAcceptance() {
  try {
    const { data } = await sb().auth.getUser()
    const at = data.user?.user_metadata?.terms_accepted_at
    if (!data.user || typeof at !== 'string' || !at) return
    await sb().from('users').update({ terms_accepted_at: at }).eq('id', data.user.id).is('terms_accepted_at', null)
  } catch {
    /* logged in the app; never fatal */
  }
}

async function uid() {
  const { data } = await sb().auth.getUser()
  if (!data.user) throw new Error('Your session has ended. Please sign in again.')
  return data.user.id
}

// The simulator's delivery select (DeliveryNotifier.loadDeliveriesFromSupabase).
const SIM_SELECT = `*,
  pickup_loc:campus_locations!pickup_location_id(id, name, latitude, longitude),
  dropoff_loc:campus_locations!dropoff_location_id(id, name, latitude, longitude),
  orders!order_id(*, vendor:users!vendor_id(full_name, business_name), campus_locations!delivery_location_id(name), order_items(product_name, quantity, weight_grams))`

async function hydrate(rows: OrderRow[], viewer: Profile): Promise<Order[]> {
  if (!rows.length) return []
  const ids = rows.map((r) => r.id)

  // Vendor names: active vendor rows are readable by every signed-in user.
  const vendorIds = [...new Set(rows.map((r) => r.vendor_id).filter(Boolean))] as string[]
  const vendors = vendorIds.length
    ? ((ok(await sb().from('users').select('id, business_name, full_name').in('id', vendorIds)) ?? []) as Pick<Profile, 'id' | 'business_name' | 'full_name'>[])
    : []
  const vendorName = new Map(vendors.map((v) => [v.id, v.business_name ?? v.full_name]))

  // Customer names: admins read users directly; vendors may not, so they go
  // through get_order_counterpart like the app does.
  const customerName = new Map<string, string>()
  if (viewer.role === 'admin') {
    const cids = [...new Set(rows.map((r) => r.user_id).filter(Boolean))] as string[]
    if (cids.length) {
      const cs = (ok(await sb().from('users').select('id, full_name').in('id', cids)) ?? []) as Pick<Profile, 'id' | 'full_name'>[]
      cs.forEach((c) => customerName.set(c.id, c.full_name))
    }
  } else if (viewer.role === 'vendor') {
    await Promise.all(
      rows.slice(0, 40).map(async (r) => {
        const res = await sb().rpc('get_order_counterpart', { p_order_id: r.id })
        const row = Array.isArray(res.data) ? res.data[0] : res.data
        if (row?.display_name) customerName.set(r.id, row.display_name)
      }),
    )
  }

  const unread = new Map<string, number>()
  const msgs = (ok(await sb().from('order_messages').select('order_id, sender_id').in('order_id', ids).is('read_at', null)) ?? []) as { order_id: string; sender_id: string }[]
  msgs.filter((m) => m.sender_id !== viewer.id).forEach((m) => unread.set(m.order_id, (unread.get(m.order_id) ?? 0) + 1))

  return rows.map(({ order_items, deliveries, ...o }) => ({
    ...o,
    items: order_items ?? [],
    delivery: Array.isArray(deliveries) ? (deliveries[0] ?? null) : deliveries,
    vendor_name: (o.vendor_id && vendorName.get(o.vendor_id)) || null,
    customer_name: (viewer.role === 'admin' ? o.user_id && customerName.get(o.user_id) : customerName.get(o.id)) || null,
    unread_messages: unread.get(o.id) ?? 0,
  }))
}

const toReviews = (rows: Record<string, unknown>[] | null) =>
  (rows ?? []).map((r, i) => ({
    id: String(r.id ?? i),
    rating: Number(r.rating ?? 0),
    comment: (r.comment as string) ?? null,
    reviewer_name: ((r.reviewer_name ?? r.user_name ?? r.full_name) as string) ?? null,
    created_at: String(r.created_at ?? nowIso()),
  }))

export const liveApi: Api = {
  async currentUserId() {
    const { data } = await sb().auth.getSession()
    return data.session?.user.id ?? null
  },
  onAuthChange(cb) {
    const { data } = sb().auth.onAuthStateChange(() => cb())
    return () => data.subscription.unsubscribe()
  },
  async signIn(email, password) {
    const normalized = email.trim().toLowerCase()
    const res = await sb().auth.signInWithPassword({ email: normalized, password })
    if (res.error) {
      const code = res.error.code?.toLowerCase() ?? ''
      const msg = res.error.message.toLowerCase()
      // AuthNotifier.login: an unverified email gets a fresh sign-up code
      // and the verification step, not a dead end.
      if ((code === 'email_not_confirmed' || msg.includes('email not confirmed')) && !isAdminEmail(normalized)) {
        const resend = await sb().auth.resend({ type: 'signup', email: normalized })
        // Only claim a code was sent when one was.
        if (resend.error && !isRateLimited(resend.error)) throw new Error(`Your email isn't verified yet. ${authMessage(resend.error)}`)
        throw new EmailNotVerifiedError(
          resend.error
            ? "Your email isn't verified yet. Please enter the code sent to your email."
            : "Your email isn't verified yet. We sent you a new code.",
        )
      }
      // A Google-only account gets told why its password failed.
      if (msg.includes('invalid login credentials') || code === 'invalid_credentials') {
        if (await liveApi.isGoogleOnlyAccount(normalized)) throw new Error('This account uses Google sign-in. Use Continue with Google to sign in.')
      }
      throw new Error(authMessage(res.error))
    }
    const profile = await me().catch(async (e) => {
      await sb().auth.signOut()
      throw e
    })
    const reject = async (message: string) => {
      await sb().auth.signOut()
      throw new Error(message)
    }
    if (profile.account_status === 'suspended') await reject('Your account has been suspended. Please contact the administrator.')
    if (profile.account_status === 'deleted') await reject('This account is no longer available. Please contact the administrator.')
    // Vendor login rules from AuthNotifier.login.
    if (profile.role === 'vendor' && profile.vendor_status === 'suspended') await reject('Your vendor account has been suspended. Please contact the administrator.')
    if (profile.role === 'vendor' && profile.vendor_status === 'rejected') await reject('Your vendor application was rejected. Please contact the administrator.')
    await recordTermsAcceptance()
    return profile
  },
  async isGoogleOnlyAccount(email) {
    const res = await sb().rpc('check_google_only_account', { p_email: email.trim().toLowerCase() })
    return !res.error && res.data === true
  },
  async signInWithGoogle() {
    // The web equivalent of the app's OAuth deep link: Google returns here.
    authOk(await sb().auth.signInWithOAuth({ provider: 'google', options: { redirectTo: `${window.location.origin}/auth/callback` } }))
  },
  async completeGoogleSignIn() {
    const { data } = await sb().auth.getSession()
    const authUser = data.session?.user
    if (!authUser) throw new Error('Google sign-in did not complete. Please try again.')
    // _handleOAuthSignInSuccess: the users row comes from a trigger, so wait for it briefly.
    let row: Profile | null = null
    for (let i = 0; i < 12 && !row; i++) {
      row = (ok(await sb().from('users').select('*').eq('id', authUser.id).maybeSingle()) as Profile | null) ?? null
      if (!row) await new Promise((r) => setTimeout(r, 250))
    }
    if (!row) throw new Error('Your account profile is not ready yet. Please try again in a moment.')
    const reject = async (message: string) => {
      await sb().auth.signOut()
      throw new Error(message)
    }
    if (row.account_status === 'suspended') await reject('Your account has been suspended. Please contact the administrator.')
    if (row.account_status === 'deleted') await reject('This account is no longer available. Please contact the administrator.')
    if (row.role === 'admin' || isAdminEmail(row.email)) await reject('Administrator accounts must sign in using email and password.')
    return row
  },
  async accountStatus(userId) {
    const row = ok(await sb().from('users').select('account_status').eq('id', userId).maybeSingle()) as { account_status: Profile['account_status'] } | null
    return row?.account_status ?? null
  },
  async resendSignUpCode(email) {
    authOk(await sb().auth.resend({ type: 'signup', email: email.trim().toLowerCase() }))
  },
  async sendEmailVerificationCode() {
    const { data } = await sb().auth.getUser()
    const email = data.user?.email
    if (!email) throw new Error('Your session has ended. Please sign in again.')
    // The same emailed code as sign-in (the Magic Link template's {{ .Token }}).
    authOk(await sb().auth.signInWithOtp({ email, options: { shouldCreateUser: false } }))
  },
  async verifyEmailCode(code) {
    const { data } = await sb().auth.getUser()
    const email = data.user?.email
    if (!email) throw new Error('Your session has ended. Please sign in again.')
    authOk(await sb().auth.verifyOtp({ type: 'email', email, token: code.trim() }))
    // The new session was made by the code, so the database accepts it as proof.
    const res = await sb().rpc('confirm_email_verified')
    if (res.error && !/could not find the function|does not exist/i.test(res.error.message)) throw new Error(res.error.message)
  },
  async checkEmail(email) {
    // Never blocks on an outage: the emailed code still proves the inbox.
    try {
      const { data, error } = await sb().functions.invoke('check-email', { body: { email: email.trim().toLowerCase() } })
      if (error || !data || typeof (data as EmailCheck).ok !== 'boolean') return { ok: true, unchecked: true }
      return data as EmailCheck
    } catch {
      return { ok: true, unchecked: true }
    }
  },
  async signUp(input) {
    if (isAdminEmail(input.email)) throw new Error('Admin accounts cannot be registered through this form.')
    const email = input.email.trim().toLowerCase()
    // Migration 34: only real addresses that can receive mail.
    const check = await liveApi.checkEmail(email)
    if (!check.ok) throw new EmailRejectedError(check.message ?? "This email address can't receive mail.", check.suggestion)
    // The handle_new_auth_user trigger writes public.users from this metadata.
    const res = await sb().auth.signUp({
      email,
      password: input.password,
      options: {
        data: {
          full_name: input.fullName.trim(),
          phone_number: input.phone,
          requested_role: input.role,
          business_name: input.businessName?.trim(),
          business_category: input.businessCategory,
          business_description: input.businessDescription?.trim(),
          campus_location_id: input.campusLocationId,
          // Copied to users.terms_accepted_at once a session exists.
          terms_accepted_at: input.termsAcceptedAt,
        },
      },
    })
    if (res.error) {
      // An address that already has an account: say so, send nothing, and
      // open no code step (AuthNotifier.register does the same).
      if (isAlreadyRegistered(res.error)) throw new Error('This email is already registered. Sign in instead, or use a different email.')
      throw new Error(authMessage(res.error))
    }
    // With email confirmation on, Supabase answers a verified address with a
    // user that has no identities and sends nothing.
    if (res.data.user && !res.data.session && res.data.user.identities?.length === 0) {
      throw new Error('This email is already registered. Sign in instead, or use a different email.')
    }
    // With email confirmation off, the account is signed in already.
    if (res.data.session) {
      await recordTermsAcceptance()
      return { verify: false }
    }
    return { verify: true }
  },
  async verifySignUpCode(email, code) {
    authOk(await sb().auth.verifyOtp({ type: 'signup', email: email.trim().toLowerCase(), token: code.trim() }))
    await recordTermsAcceptance()
  },
  async sendPasswordReset(email) {
    authOk(await sb().auth.resetPasswordForEmail(email.trim().toLowerCase()))
  },
  async resetPassword(email, code, newPassword) {
    authOk(await sb().auth.verifyOtp({ type: 'recovery', email: email.trim().toLowerCase(), token: code.trim() }))
    authOk(await sb().auth.updateUser({ password: newPassword }))
    await sb().auth.signOut()
  },
  async changePassword(currentPassword, newPassword) {
    const { data } = await sb().auth.getUser()
    const email = data.user?.email
    if (!email) throw new Error('Your session has ended. Please sign in again.')
    // change_password_page.dart: verify the current password first.
    const check = await sb().auth.signInWithPassword({ email, password: currentPassword })
    if (check.error) throw new Error('Your current password is incorrect.')
    ok(await sb().auth.updateUser({ password: newPassword }))
  },
  async changeEmail(newEmail) {
    ok(await sb().auth.updateUser({ email: newEmail.trim().toLowerCase() }))
  },
  async signOut() {
    await sb().auth.signOut()
  },
  async profile(id) {
    return (ok(await sb().from('users').select('*').eq('id', id).maybeSingle()) as Profile | null) ?? null
  },
  async updateProfile(id, patch) {
    ok(await sb().from('users').update({ ...patch, updated_at: nowIso() }).eq('id', id))
  },

  async locations() {
    return rows(await sb().from('campus_locations').select('*').order('name'))
  },
  async weather() {
    const row = ok(await sb().from('weather_safety').select('*').order('updated_at', { ascending: false }).limit(1).maybeSingle())
    return (row ?? { safety_status: 'safe', updated_at: nowIso() }) as Weather
  },
  async vendors() {
    const rows = ok(await sb().from('users').select('*').eq('role', 'vendor').eq('vendor_status', 'active').eq('account_status', 'active').order('business_name')) as Profile[]
    const ratings = ok(await sb().from('vendor_ratings_summary').select('*')) as { vendor_id: string; average_rating: number; review_count: number }[]
    const byId = new Map(ratings.map((r) => [r.vendor_id, r]))
    return rows.map((v): Vendor => ({ ...v, rating: byId.get(v.id)?.average_rating ?? null, review_count: byId.get(v.id)?.review_count ?? 0 }))
  },
  async products(opts) {
    let q = sb().from('products').select('*').order('created_at', { ascending: false })
    if (opts?.vendorId) q = q.eq('vendor_id', opts.vendorId)
    if (!opts?.includeInactive) q = q.eq('is_active', true)
    const rows = ok(await q) as Product[]
    const ratings = ok(await sb().from('product_ratings_summary').select('*')) as { product_id: string; average_rating: number; review_count: number }[]
    const byId = new Map(ratings.map((r) => [r.product_id, r]))
    return rows.map((p) => ({ ...p, rating: byId.get(p.id)?.average_rating ?? null, review_count: byId.get(p.id)?.review_count ?? 0 }))
  },
  async product(id) {
    return ok(await sb().from('products').select('*').eq('id', id).maybeSingle())
  },
  async vendorReviews(vendorId) {
    return toReviews(ok(await sb().rpc('get_vendor_reviews', { p_vendor_id: vendorId })))
  },
  async productReviews(productId) {
    return toReviews(ok(await sb().rpc('get_product_reviews', { p_product_id: productId })))
  },

  async orders() {
    const viewer = await me()
    let q = sb().from('orders').select(ORDER_SELECT).order('created_at', { ascending: false }).limit(300)
    if (viewer.role === 'user') q = q.eq('user_id', viewer.id)
    if (viewer.role === 'vendor') q = q.eq('vendor_id', viewer.id)
    return hydrate((ok(await q) ?? []) as unknown as OrderRow[], viewer)
  },
  async order(id) {
    const viewer = await me()
    const row = ok(await sb().from('orders').select(ORDER_SELECT).eq('id', id).maybeSingle())
    if (!row) return null
    return (await hydrate([row as unknown as OrderRow], viewer))[0] ?? null
  },
  async quoteOrderFee(input) {
    const raw = ok(
      await sb().rpc('quote_order_fee', {
        p_vendor_id: input.vendorId,
        p_delivery_location_id: input.dropoffLocationId,
        p_items: input.items,
      }),
    ) as Record<string, unknown> | null
    // Postgres numerics may arrive as strings. A missing price is an error,
    // never a zero shown as if it were the charge.
    const num = (v: unknown) => (typeof v === 'number' ? v : Number(v ?? NaN))
    const need = (key: string) => {
      const n = num(raw?.[key])
      if (!Number.isFinite(n)) throw new Error('The delivery fee could not be calculated.')
      return n
    }
    const opt = (v: unknown) => (Number.isFinite(num(v)) ? num(v) : 0)
    const b = (raw?.breakdown ?? {}) as Record<string, unknown>
    return {
      subtotal: need('subtotal'),
      deliveryFee: need('delivery_fee'),
      totalAmount: need('total_amount'),
      totalWeightGrams: opt(raw?.total_weight_grams),
      tripsRequired: Math.max(1, Math.round(opt(raw?.trips_required))),
      distanceKm: opt(raw?.distance_km),
      isCaution: raw?.is_caution === true,
      breakdown: { base: opt(b.base), distance: opt(b.distance), weight: opt(b.weight), extraTrip: opt(b.extra_trip), weather: opt(b.weather) },
    }
  },
  async placeOrder(input) {
    const id = ok(
      await sb().rpc('place_order', {
        p_vendor_id: input.vendorId,
        p_delivery_location_id: input.dropoffLocationId,
        p_subtotal: input.subtotal,
        p_delivery_fee: input.deliveryFee,
        p_total_amount: input.totalAmount,
        p_payment_method: input.paymentMethod,
        p_items: input.items,
        p_notes: input.notes ?? null,
      }),
    )
    return String(id)
  },
  async startOnlinePayment(orderId) {
    const { data, error } = await sb().functions.invoke('create-xendit-payment', { body: { order_id: orderId } })
    if (error) throw new Error(error.message)
    const url = (data as { invoice_url?: string; error?: string } | null)?.invoice_url
    if (!url) throw new Error((data as { error?: string } | null)?.error ?? 'Could not start payment. Please try again.')
    return url
  },
  async cancelOrder(id) {
    const res = ok(await sb().rpc('customer_cancel_order', { p_order_id: id }))
    if (res === false) throw new Error('This order can no longer be cancelled.')
  },
  async orderReviews(orderId) {
    // ReviewProvider: existing store and product reviews for this order.
    const store = ok(await sb().from('store_reviews').select('rating, comment').eq('order_id', orderId).maybeSingle()) as { rating: number; comment: string | null } | null
    const products = rows<{ product_id: string; rating: number; comment: string | null }>(await sb().from('product_reviews').select('product_id, rating, comment').eq('order_id', orderId))
    return { store, products: Object.fromEntries(products.map((p) => [p.product_id, { rating: p.rating, comment: p.comment }])) }
  },
  async submitReview(orderId, draft) {
    const res = ok(
      await sb().rpc('submit_order_reviews', {
        p_order_id: orderId,
        p_store_rating: draft.storeRating,
        p_store_comment: draft.storeComment.trim() || null,
        p_product_reviews: draft.products.map((p) => ({ product_id: p.product_id, rating: p.rating, ...(p.comment?.trim() ? { comment: p.comment.trim() } : {}) })),
      }),
    )
    if (res === false) throw new Error('Could not save your review. Please try again.')
  },
  async telemetry(deliveryId): Promise<Telemetry | null> {
    const row = ok(
      await sb().from('drone_telemetry').select('latitude, longitude, altitude, speed, battery_level, recorded_at').eq('delivery_id', deliveryId).order('recorded_at', { ascending: false }).limit(1).maybeSingle(),
    ) as Telemetry | null
    return row?.latitude != null ? row : null
  },

  async messages(orderId) {
    return rows(await sb().from('order_messages').select('*').eq('order_id', orderId).order('created_at'))
  },
  async chatCounterpart(orderId) {
    // Vendors cannot read customer rows, so names come from this RPC (as in the app).
    const data = ok(await sb().rpc('get_order_counterpart', { p_order_id: orderId }))
    const row = (Array.isArray(data) ? data[0] : data) as Record<string, string | null> | undefined
    if (!row?.display_name?.trim()) return null
    return {
      id: String(row.counterpart_id),
      name: row.display_name.trim(),
      role: row.counterpart_role === 'vendor' ? 'vendor' : 'customer',
      avatarUrl: row.avatar_url?.trim() || null,
    }
  },
  async sendMessage(orderId, text) {
    const viewer = await me()
    ok(await sb().from('order_messages').insert({ order_id: orderId, sender_id: viewer.id, message: text.trim() }))
  },
  async markMessagesRead(orderId) {
    await sb().rpc('mark_order_messages_read', { p_order_id: orderId })
  },
  subscribeMessages(orderId, cb) {
    const channel = sb()
      .channel(`order-chat-${orderId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'order_messages', filter: `order_id=eq.${orderId}` }, () => cb())
      .subscribe()
    return () => {
      sb().removeChannel(channel)
    }
  },

  async notifications() {
    const viewer = await me()
    return rows(await sb().from('notifications').select('*').eq('user_id', viewer.id).order('created_at', { ascending: false }).limit(100))
  },
  async markNotificationRead(id) {
    ok(await sb().rpc('mark_notification_read', { p_notification_id: id }))
  },
  async markAllNotificationsRead() {
    ok(await sb().rpc('mark_all_notifications_read'))
  },

  async submitReport(input) {
    const viewer = await me()
    // help_support_page.dart payload; the new id opens the report's thread.
    const row = ok(
      await sb().from('support_reports').insert({
        user_id: viewer.id,
        subject: input.subject.trim(),
        message: input.message.trim(),
        category: input.category,
        status: 'open',
        ...(input.orderId ? { order_id: input.orderId } : {}),
        ...(input.deliveryId ? { delivery_id: input.deliveryId } : {}),
      }).select('id').single(),
    ) as { id: string }
    return row.id
  },
  async reports() {
    const viewer = await me()
    // mySupportReportsProvider: each report with its replies' times and read state.
    let q = sb().from('support_reports').select('*, support_messages(created_at, sender_id, read_at)').order('created_at', { ascending: false })
    if (viewer.role !== 'admin') q = q.eq('user_id', viewer.id)
    const rows = (ok(await q) as Record<string, unknown>[]).map((r) => withThreadStats(r, viewer.id))
    // Most recently active first, as the app lists them.
    if (viewer.role !== 'admin') rows.sort((a, b) => lastActivity(b).localeCompare(lastActivity(a)))
    if (viewer.role !== 'admin' || !rows.length) return rows
    const people = ok(await sb().from('users').select('id, full_name').in('id', [...new Set(rows.map((r) => r.user_id))])) as Pick<Profile, 'id' | 'full_name'>[]
    const names = new Map(people.map((p) => [p.id, p.full_name]))
    return rows.map((r) => ({ ...r, reporter_name: names.get(r.user_id) ?? null }))
  },
  async report(id) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return null
    return (ok(await sb().from('support_reports').select('*').eq('id', id).maybeSingle()) as SupportReport | null) ?? null
  },
  async supportMessages(reportId) {
    const rows = ok(await sb().from('support_messages').select(SUPPORT_COLUMNS).eq('report_id', reportId).order('created_at', { ascending: true })) as Record<string, unknown>[]
    return rows.map(toSupportMessage)
  },
  async sendSupportMessage(reportId, text, photos) {
    // Everything checkable locally is checked before any upload, as in the app.
    if (photos.length > SUPPORT_MAX_PHOTOS) throw new Error(`You can attach up to ${SUPPORT_MAX_PHOTOS} photos per message.`)
    const trimmed = text.trim()
    if (!trimmed && !photos.length) throw new Error('Write a message or attach a photo.')
    if (trimmed.length > SUPPORT_MESSAGE_MAX) throw new Error(`Message is too long (${trimmed.length}/${SUPPORT_MESSAGE_MAX} characters).`)
    const exts = photos.map(checkImage)
    const sender = await uid()
    const paths: string[] = []
    for (const [i, file] of photos.entries()) {
      const path = `${reportId}/${crypto.randomUUID()}${exts[i]}`
      const res = await sb().storage.from(SUPPORT_BUCKET).upload(path, file, { contentType: file.type })
      if (res.error) throw new Error(`Photo upload failed: ${res.error.message}`)
      paths.push(path)
    }
    const row = ok(
      await sb().from('support_messages').insert({ report_id: reportId, sender_id: sender, message: trimmed, attachments: paths }).select(SUPPORT_COLUMNS).single(),
    ) as Record<string, unknown>
    return toSupportMessage(row)
  },
  supportAttachmentUrl(path) {
    const cached = signedUrls.get(path)
    if (cached && Date.now() - cached.signedAt < SIGNED_URL_REUSE_MS) return cached.url
    const url = sb()
      .storage.from(SUPPORT_BUCKET)
      .createSignedUrl(path, SIGNED_URL_SECONDS)
      .then((res) => {
        if (res.error || !res.data?.signedUrl) throw new Error(res.error?.message ?? 'This photo could not be loaded.')
        return res.data.signedUrl
      })
    signedUrls.set(path, { url, signedAt: Date.now() })
    // A failed signing is dropped so a retry asks again.
    url.catch(() => signedUrls.delete(path))
    return url
  },
  async markSupportRead(reportId) {
    // Also clears the report's bell notifications (migration 29 matches both metadata keys).
    await sb().rpc('mark_support_messages_read', { p_report_id: reportId })
  },
  subscribeSupportMessages(reportId, cb) {
    const channel = sb()
      .channel(`support-chat-${reportId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'support_messages', filter: `report_id=eq.${reportId}` }, () => cb())
      .subscribe()
    return () => {
      sb().removeChannel(channel)
    }
  },
  async supportUserName(userId) {
    const row = ok(await sb().from('users').select('full_name, business_name, email').eq('id', userId).maybeSingle()) as Record<string, string | null> | null
    for (const k of ['business_name', 'full_name', 'email']) if (row?.[k]?.trim()) return row[k]!.trim()
    return null
  },
  async updateReport(id, patch) {
    const body: Record<string, unknown> = { ...patch }
    if (patch.status) body.resolved_at = patch.status === 'resolved' ? nowIso() : null
    ok(await sb().from('support_reports').update(body).eq('id', id))
  },

  async saveProduct({ id, ...fields }) {
    const viewer = await me()
    if (id) ok(await sb().from('products').update({ ...fields, updated_at: nowIso() }).eq('id', id).eq('vendor_id', viewer.id))
    else ok(await sb().from('products').insert({ ...fields, vendor_id: viewer.id }))
  },
  async deleteProduct(id) {
    const viewer = await me()
    ok(await sb().from('products').delete().eq('id', id).eq('vendor_id', viewer.id))
  },
  async setOrderStatus(id, status) {
    const body: Record<string, unknown> = { order_status: status, updated_at: nowIso() }
    if (status === 'cancelled' || status === 'rejected') body.cancellation_reason = 'vendor'
    ok(await sb().from('orders').update(body).eq('id', id))
  },
  async markOrderReady(id) {
    const res = ok(await sb().rpc('vendor_mark_order_ready', { p_order_id: id })) as { drone_dispatched?: boolean; message?: string } | null
    return (
      res?.message ??
      (res?.drone_dispatched
        ? 'Order is ready for drone pickup. Drone dispatch initiated.'
        : 'No drone is free right now. The order is waiting for the next one.')
    )
  },

  async users() {
    return rows(await sb().from('users').select('*').order('created_at', { ascending: false }))
  },
  async setAccountStatus(id, status) {
    ok(await sb().from('users').update({ account_status: status, updated_at: nowIso() }).eq('id', id))
  },
  async setVendorStatus(id, status) {
    const body: Record<string, unknown> = { vendor_status: status, updated_at: nowIso() }
    if (status === 'active') Object.assign(body, { role: 'vendor', account_status: 'active' })
    ok(await sb().from('users').update(body).eq('id', id))
  },
  async deleteUser(id) {
    ok(await sb().rpc('delete_user_account', { p_target_user_id: id }))
  },
  async drones() {
    return rows(await sb().from('drones').select('*').order('drone_code'))
  },
  async rechargeDrone(id) {
    ok(await sb().from('drones').update({ battery_level: 100, status: 'available', updated_at: nowIso() }).eq('id', id))
  },
  async statusLogs(deliveryId) {
    let q = sb().from('delivery_status_logs').select('*').order('created_at', { ascending: false }).limit(200)
    if (deliveryId) q = q.eq('delivery_id', deliveryId)
    return rows(await q)
  },
  async setWeatherOverride(state) {
    // WeatherNotifier.setSimulatedWeather: a 2-hour override.
    ok(await sb().rpc('set_simulated_weather', { p_safety_status: state, p_duration_hours: 2 }))
  },
  async clearWeatherOverride() {
    ok(await sb().rpc('clear_weather_override'))
  },
  async zones() {
    return rows(await sb().from('no_fly_zones').select('*').order('name'))
  },
  async saveZone({ id, ...fields }) {
    if (id) ok(await sb().from('no_fly_zones').update({ ...fields, updated_at: nowIso() }).eq('id', id))
    else ok(await sb().from('no_fly_zones').insert(fields))
  },
  async deleteZone(id) {
    ok(await sb().from('no_fly_zones').delete().eq('id', id))
  },

  // ── Storage: the app's buckets and file paths ──────────────────────────
  async uploadAvatar(file) {
    const ext = checkImage(file)
    const id = await uid()
    const url = await upload('avatars', `${id}/avatar${ext}`, file)
    ok(await sb().from('users').update({ avatar_url: url, updated_at: nowIso() }).eq('id', id))
    return url
  },
  async uploadStoreLogo(file, name = 'logo') {
    const ext = checkImage(file)
    const id = await uid()
    const url = await upload('vendor-logos', `${id}/${name}${ext}`, file)
    ok(await sb().from('users').update({ business_logo_url: url, updated_at: nowIso() }).eq('id', id))
    return url
  },
  async removeStoreLogo() {
    const id = await uid()
    ok(await sb().from('users').update({ business_logo_url: null, updated_at: nowIso() }).eq('id', id))
  },
  async uploadProductImage(file) {
    const ext = checkImage(file)
    const id = await uid()
    return upload('product-images', `${id}/prod_${Date.now()}${ext}`, file)
  },

  async fleetTelemetry() {
    // Latest point per drone (telemetry_provider fleet stream).
    const recent = rows<Telemetry & { drone_id: string | null }>(
      await sb().from('drone_telemetry').select('drone_id, latitude, longitude, altitude, speed, battery_level, recorded_at').order('recorded_at', { ascending: false }).limit(50),
    )
    const seen = new Set<string>()
    return recent.filter((t) => t.drone_id && t.latitude != null && !seen.has(t.drone_id) && seen.add(t.drone_id)) as (Telemetry & { drone_id: string })[]
  },
  async safetyChecks() {
    const res = await sb().from('delivery_safety_checks').select('*').order('checked_at', { ascending: false }).limit(10)
    return res.error ? null : (res.data as Record<string, unknown>[])
  },

  // ── Flight simulator primitives: the same calls DeliveryNotifier makes ──
  async simDeliveries() {
    const viewer = await me()
    const data = rows<Record<string, any>>(await sb().from('deliveries').select(SIM_SELECT).order('created_at', { ascending: false }).limit(200))
    return data
      .filter((d) => {
        const o = d.orders
        if (viewer.role === 'admin') return true
        if (!o) return false
        return viewer.role === 'vendor' ? o.vendor_id === viewer.id : o.user_id === viewer.id
      })
      .map((d): SimDelivery => {
        const o = d.orders ?? {}
        const items = (o.order_items ?? []) as { weight_grams?: number; quantity?: number }[]
        const grams = items.reduce((s, i) => s + (i.weight_grams ?? 0) * (i.quantity ?? 1), 0)
        const sender = o.vendor?.business_name ?? o.vendor?.full_name ?? 'Vendor Shop'
        return {
          id: String(d.id),
          order_id: String(d.order_id ?? o.id),
          status: d.status,
          progress: d.status === 'delivered' ? 1 : Math.min(1, Math.max(0, Number(d.progress ?? 0))),
          drone_id: d.drone_id ?? null,
          trips_required: Number(d.trips_required ?? 1),
          trips_completed: Number(d.trips_completed ?? 0),
          pickup_name: d.pickup_loc?.name ?? sender,
          dropoff_name: d.dropoff_loc?.name ?? o.campus_locations?.name ?? 'UCLM Campus',
          payload_kg: grams / 1000,
          delivered_at: d.delivery_completed_at ?? null,
          created_at: d.created_at,
        }
      })
  },
  async hubCoords(): Promise<Coords> {
    const row = ok(await sb().from('campus_locations').select('latitude, longitude').eq('location_code', 'BASE-HUB').maybeSingle()) as { latitude: number | null; longitude: number | null } | null
    return row?.latitude != null && row?.longitude != null ? [row.latitude, row.longitude] : DEFAULT_HUB
  },
  async recordTelemetry(t) {
    ok(
      await sb().rpc('record_simulated_telemetry', {
        p_delivery_id: t.deliveryId,
        p_latitude: t.latitude,
        p_longitude: t.longitude,
        p_altitude: t.altitude,
        p_speed: t.speed,
        p_battery_level: t.battery,
        p_signal_strength: t.signal,
        p_heading: t.heading,
        p_event_type: t.event,
        p_progress: t.progress,
      }),
    )
  },
  async setDroneBattery(droneId, battery) {
    ok(await sb().from('drones').update({ battery_level: battery }).eq('id', droneId))
  },
  async setDroneStatus(droneId, status) {
    ok(await sb().from('drones').update({ status, updated_at: nowIso() }).eq('id', droneId))
  },
  async confirmPickup(deliveryId) {
    ok(await sb().rpc('confirm_package_pickup', { p_delivery_id: deliveryId }))
  },
  async completeDelivery(deliveryId) {
    ok(await sb().rpc('complete_delivery_order', { p_delivery_id: deliveryId }))
  },
  async arriveAtVendorForNextTrip(deliveryId) {
    ok(await sb().rpc('arrive_at_vendor_for_next_trip', { p_delivery_id: deliveryId }))
  },
  async completeDroneReturn(droneId) {
    ok(await sb().rpc('complete_drone_return', { p_drone_id: droneId }))
  },
  async claimSimLease(droneId) {
    const res = await sb().rpc('claim_drone_sim_lease', { p_drone_id: droneId })
    return !res.error && res.data === true
  },
  async lastFinishedDeliveryForDrone(droneId) {
    const row = ok(
      await sb().from('deliveries').select('id').eq('drone_id', droneId).in('status', ['delivered', 'cancelled']).order('updated_at', { ascending: false }).limit(1).maybeSingle(),
    ) as { id: string } | null
    return row?.id ?? null
  },
  async recoverStaleReturningDrone(droneId) {
    const res = await sb().rpc('recover_stale_returning_drone', { p_drone_id: droneId })
    return !res.error && (res.data as { recovered?: boolean } | null)?.recovered === true
  },

  // ── Realtime: the tables the app's channels listen to ──────────────────
  subscribeChanges(scope, cb) {
    const tables = ['orders', 'deliveries', 'drones', 'weather_safety', 'order_messages', 'products', 'support_reports', 'support_messages', 'users']
    if (scope.role === 'admin') tables.push('drone_telemetry', 'delivery_status_logs')
    let ch = sb().channel(`aerodrop-web-${scope.userId}`)
    for (const table of tables) ch = ch.on('postgres_changes', { event: '*', schema: 'public', table }, () => cb())
    ch = ch.on('postgres_changes', { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${scope.userId}` }, () => cb())
    ch.subscribe()
    return () => {
      sb().removeChannel(ch)
    }
  },
}
