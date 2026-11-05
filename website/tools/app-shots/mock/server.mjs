// Minimal Supabase stand-in for the screenshot harness.
// - /rest/v1  : a small PostgREST (embedded selects, filters, order, limit, writes)
// - /auth/v1  : password sign-in, OTP send/verify, user
// - /rest/v1/rpc/* : the RPCs the app calls while browsing and flying
// - everything else: the Flutter web build (same origin, so no CORS dance)
import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { extname, join } from 'node:path'
import * as seed from './data.mjs'

// Mutable so /__reset can restore the starting scene between capture passes.
let { db, ids } = seed

const PORT = Number(process.env.PORT ?? 7070)
const WEB = new URL('../harness/build/web/', import.meta.url).pathname
const uuid = () => crypto.randomUUID()
const now = () => new Date().toISOString()

// ── Relations ───────────────────────────────────────────────────────────────
const singular = (t) => ({ users: 'user', orders: 'order', deliveries: 'delivery', campus_locations: 'campus_location', products: 'product', drones: 'drone', vendors: 'vendor' })[t] ?? t.replace(/s$/, '')

function splitTop(s) {
  const out = []
  let depth = 0
  let cur = ''
  for (const ch of s) {
    if (ch === '(') depth++
    if (ch === ')') depth--
    if (ch === ',' && depth === 0) {
      out.push(cur.trim())
      cur = ''
    } else cur += ch
  }
  if (cur.trim()) out.push(cur.trim())
  return out
}

function parseSelect(sel = '*') {
  return splitTop(sel.replace(/\s+/g, ' ')).map((item) => {
    const m = item.match(/^(?:([a-z_]+):)?([a-z_]+)(?:!([a-z_]+))?\((.*)\)$/s)
    if (!m) return { col: item.trim() }
    return { alias: m[1] ?? m[2], table: m[2], hint: m[3], inner: m[3] === 'inner', select: m[4] }
  })
}

function embed(fromTable, row, e) {
  const target = db[e.table] ?? []
  const hintCol = e.hint && e.hint !== 'inner' && e.hint !== 'left' ? e.hint : null
  const fk = hintCol ?? `${singular(e.table)}_id`
  if (fk in row) {
    const hit = target.find((r) => r.id === row[fk])
    return hit ? shape(e.table, hit, e.select) : null
  }
  const back = `${singular(fromTable)}_id`
  const many = target.filter((r) => r[back] === row.id).map((r) => shape(e.table, r, e.select))
  // deliveries.order_id is UNIQUE, so PostgREST returns one object.
  return e.table === 'deliveries' && fromTable === 'orders' ? (many[0] ?? null) : many
}

function shape(table, row, sel) {
  const parts = parseSelect(sel)
  const out = parts.some((p) => p.col === '*') || parts.every((p) => !p.col) ? { ...row } : {}
  for (const p of parts) {
    if (p.col && p.col !== '*') out[p.col] = row[p.col] ?? null
    if (p.table) out[p.alias] = embed(table, row, p)
  }
  return out
}

// ── Filters ─────────────────────────────────────────────────────────────────
function test(val, expr) {
  let neg = false
  if (expr.startsWith('not.')) {
    neg = true
    expr = expr.slice(4)
  }
  const i = expr.indexOf('.')
  const op = expr.slice(0, i)
  const arg = decodeURIComponent(expr.slice(i + 1))
  const s = val == null ? null : String(val)
  let r
  switch (op) {
    case 'eq': r = s === arg; break
    case 'neq': r = s !== arg; break
    case 'gt': r = Number(val) > Number(arg) || (s ?? '') > arg; break
    case 'gte': r = s != null && (Number(val) >= Number(arg) || s >= arg); break
    case 'lt': r = s != null && (Number(val) < Number(arg) || s < arg); break
    case 'lte': r = s != null && (Number(val) <= Number(arg) || s <= arg); break
    case 'in': r = arg.replace(/^\(|\)$/g, '').split(',').map((x) => x.replace(/^"|"$/g, '')).includes(s); break
    case 'is': r = arg === 'null' ? val == null : String(val) === arg; break
    case 'ilike': case 'like': r = new RegExp('^' + arg.replace(/[%*]/g, '.*') + '$', 'i').test(s ?? ''); break
    default: r = true
  }
  return neg ? !r : r
}

const RESERVED = new Set(['select', 'order', 'limit', 'offset', 'on_conflict', 'columns'])

function query(table, params) {
  let rows = [...(db[table] ?? [])]
  const sel = params.get('select') ?? '*'
  for (const [k, v] of params) {
    if (RESERVED.has(k) || k === 'or' || k.endsWith('.order') || k.endsWith('.limit')) continue
    if (!k.includes('.')) rows = rows.filter((r) => test(r[k], v))
  }
  let shaped = rows.map((r) => shape(table, r, sel))
  // Filters on embedded resources (e.g. orders.user_id=eq.X with !inner)
  for (const [k, v] of params) {
    if (RESERVED.has(k) || !k.includes('.') || k.endsWith('.order') || k.endsWith('.limit')) continue
    const [rel, col] = k.split('.')
    shaped = shaped.filter((r) => r[rel] && test(r[rel][col], v))
  }
  const order = params.get('order')
  if (order) {
    const keys = order.split(',').map((o) => o.split('.'))
    shaped.sort((a, b) => {
      for (const [col, dir = 'asc'] of keys) {
        const x = a[col], y = b[col]
        if (x === y) continue
        const c = x == null ? 1 : y == null ? -1 : x > y ? 1 : -1
        return dir === 'desc' ? -c : c
      }
      return 0
    })
  }
  const offset = Number(params.get('offset') ?? 0)
  const limit = params.has('limit') ? Number(params.get('limit')) : undefined
  return { all: rows, shaped: shaped.slice(offset, limit != null ? offset + limit : undefined) }
}

// ── RPCs ────────────────────────────────────────────────────────────────────
const rpc = {
  // Another device "holds" the flight, so this phone only views it: the
  // telemetry stays as seeded and every theme pass sees the same moment.
  claim_drone_sim_lease: () => false,
  check_google_only_account: () => false,
  get_product_reviews: () => [],
  get_vendor_reviews: ({ p_vendor_id }) => (db.store_reviews ?? []).filter((r) => r.vendor_id === p_vendor_id),
  get_order_counterpart: ({ p_order_id }, uid) => {
    const o = db.orders.find((x) => x.id === p_order_id)
    if (!o) return []
    const otherId = o.user_id === uid ? o.vendor_id : o.user_id
    const u = db.users.find((x) => x.id === otherId)
    return [{ counterpart_id: otherId, display_name: u?.role === 'vendor' ? u.business_name : u?.full_name, counterpart_role: u?.role, avatar_url: null }]
  },
  mark_order_messages_read: ({ p_order_id }, uid) => {
    db.order_messages.forEach((m) => m.order_id === p_order_id && m.sender_id !== uid && !m.read_at && (m.read_at = now()))
    return null
  },
  mark_notification_read: ({ p_notification_id }) => {
    const n = db.notifications.find((x) => x.id === p_notification_id)
    if (n) n.is_read = true
    return null
  },
  mark_all_notifications_read: (_, uid) => {
    db.notifications.forEach((n) => n.user_id === uid && (n.is_read = true))
    return null
  },
  record_simulated_telemetry: (a) => {
    const d = db.deliveries.find((x) => x.id === a.p_delivery_id)
    db.drone_telemetry.push({
      id: uuid(), delivery_id: a.p_delivery_id, drone_id: d?.drone_id ?? null, latitude: a.p_latitude, longitude: a.p_longitude,
      altitude: a.p_altitude, speed: a.p_speed, battery_level: a.p_battery_level, signal_strength: a.p_signal_strength,
      heading: a.p_heading, event_type: a.p_event_type, recorded_at: now(),
    })
    if (d && typeof a.p_progress === 'number') d.progress = a.p_progress
    const drone = db.drones.find((x) => x.id === d?.drone_id)
    if (drone && a.p_battery_level != null) drone.battery_level = a.p_battery_level
    return null
  },
  confirm_package_pickup: () => true,
  arrive_at_vendor_for_next_trip: () => true,
  complete_delivery_order: ({ p_delivery_id }) => {
    const d = db.deliveries.find((x) => x.id === p_delivery_id)
    if (d) {
      Object.assign(d, { status: 'delivered', progress: 1, delivery_completed_at: now(), trips_completed: d.trips_required ?? 1 })
      const o = db.orders.find((x) => x.id === d.order_id)
      if (o) o.order_status = 'delivered'
    }
    return true
  },
  complete_drone_return: ({ p_drone_id }) => {
    const drone = db.drones.find((x) => x.id === p_drone_id)
    if (drone) drone.status = 'available'
    return true
  },
  recover_stale_returning_drone: () => false,
}

// ── Auth ────────────────────────────────────────────────────────────────────
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
function session(user) {
  const exp = Math.floor(Date.now() / 1000) + 86_400
  const authUser = {
    id: user.id, aud: 'authenticated', role: 'authenticated', email: user.email, email_confirmed_at: user.created_at,
    phone: '', app_metadata: { provider: 'email', providers: ['email'] }, user_metadata: { full_name: user.full_name },
    identities: [], created_at: user.created_at, updated_at: now(),
  }
  return {
    access_token: `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: user.id, email: user.email, role: 'authenticated', aud: 'authenticated', exp })}.sig`,
    token_type: 'bearer', expires_in: 86_400, expires_at: exp, refresh_token: `refresh-${user.id}`, user: authUser,
  }
}
const userFromToken = (h) => {
  try {
    const sub = JSON.parse(Buffer.from((h ?? '').replace(/^Bearer /, '').split('.')[1] ?? '', 'base64url').toString()).sub
    return db.users.find((u) => u.id === sub) ?? null
  } catch {
    return null
  }
}

// ── HTTP ────────────────────────────────────────────────────────────────────
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css', '.bin': 'application/octet-stream', '.frag': 'text/plain' }

function send(res, status, body, headers = {}) {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': '*', 'Access-Control-Expose-Headers': 'Content-Range', ...headers })
  res.end(body === undefined ? '' : JSON.stringify(body))
}

const readBody = (req) => new Promise((r) => {
  let s = ''
  req.on('data', (c) => (s += c))
  req.on('end', () => r(s ? JSON.parse(s) : null))
})

createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`)
  const p = url.pathname
  if (req.method === 'OPTIONS') return send(res, 204)
  if (p === '/__reset') {
    ;({ db, ids } = await import(`./data.mjs?v=${Date.now()}`))
    return send(res, 200, { ok: true })
  }

  try {
    if (p.startsWith('/auth/v1/')) {
      const body = await readBody(req)
      if (p === '/auth/v1/token') {
        const u = url.searchParams.get('grant_type') === 'refresh_token'
          ? db.users.find((x) => `refresh-${x.id}` === body?.refresh_token)
          : db.users.find((x) => x.email === body?.email?.toLowerCase())
        if (!u) return send(res, 400, { code: 'invalid_credentials', message: 'Invalid login credentials' })
        return send(res, 200, session(u))
      }
      if (p === '/auth/v1/otp') return send(res, 200, {})
      if (p === '/auth/v1/verify') {
        const u = db.users.find((x) => x.email === body?.email?.toLowerCase())
        return u ? send(res, 200, session(u)) : send(res, 400, { message: 'Invalid verification code.' })
      }
      if (p === '/auth/v1/user') {
        const u = userFromToken(req.headers.authorization)
        return u ? send(res, 200, session(u).user) : send(res, 401, { message: 'not signed in' })
      }
      if (p === '/auth/v1/logout') return send(res, 204)
      return send(res, 200, {})
    }

    if (p.startsWith('/rest/v1/rpc/')) {
      const fn = p.slice('/rest/v1/rpc/'.length)
      const args = (await readBody(req)) ?? Object.fromEntries(url.searchParams)
      const me = userFromToken(req.headers.authorization)
      const out = rpc[fn] ? rpc[fn](args, me?.id) : null
      return send(res, 200, out)
    }

    if (p.startsWith('/rest/v1/')) {
      const table = p.slice('/rest/v1/'.length)
      if (!db[table]) db[table] = []
      const wantsObject = (req.headers.accept ?? '').includes('vnd.pgrst.object')
      const prefer = req.headers.prefer ?? ''

      if (req.method === 'GET' || req.method === 'HEAD') {
        const { all, shaped } = query(table, url.searchParams)
        const headers = { 'Content-Range': `0-${Math.max(shaped.length - 1, 0)}/${all.length}` }
        if (wantsObject) {
          if (shaped.length !== 1) return send(res, 406, { code: 'PGRST116', details: `The result contains ${shaped.length} rows`, hint: null, message: 'JSON object requested, multiple (or no) rows returned' }, headers)
          return send(res, 200, shaped[0], headers)
        }
        return send(res, 200, req.method === 'HEAD' ? undefined : shaped, headers)
      }

      const body = await readBody(req)
      if (req.method === 'POST') {
        const rows = (Array.isArray(body) ? body : [body]).map((r) => ({ id: uuid(), created_at: now(), ...r }))
        for (const r of rows) {
          const i = db[table].findIndex((x) => x.id === r.id)
          if (i >= 0) Object.assign(db[table][i], r)
          else db[table].push(r)
        }
        if (!prefer.includes('return=representation')) return send(res, 201)
        return send(res, 201, wantsObject ? rows[0] : rows)
      }
      if (req.method === 'PATCH') {
        const { all } = query(table, new URLSearchParams([...url.searchParams].filter(([k]) => k !== 'select')))
        all.forEach((r) => Object.assign(r, body))
        if (!prefer.includes('return=representation')) return send(res, 204)
        return send(res, 200, wantsObject ? all[0] : all)
      }
      if (req.method === 'DELETE') {
        const { all } = query(table, url.searchParams)
        db[table] = db[table].filter((r) => !all.includes(r))
        return send(res, 204)
      }
    }

    if (p.startsWith('/realtime/') || p.startsWith('/storage/') || p.startsWith('/functions/')) return send(res, 404, { message: 'not in mock' })

    // Static Flutter build
    const file = join(WEB, p === '/' ? 'index.html' : p)
    try {
      const data = await readFile(file)
      res.writeHead(200, { 'Content-Type': MIME[extname(file)] ?? 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'credentialless' })
      return res.end(data)
    } catch {
      const data = await readFile(join(WEB, 'index.html'))
      res.writeHead(200, { 'Content-Type': 'text/html' })
      return res.end(data)
    }
  } catch (e) {
    console.error('mock error', req.method, req.url, e)
    send(res, 500, { message: String(e) })
  }
}).listen(PORT, () => console.log(`mock supabase + app on http://localhost:${PORT} (ids: ${Object.keys(ids).length})`))
