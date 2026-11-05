import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv, type Plugin, type PluginOption } from 'vite'

/** True for keys that must never ship to a browser: sb_secret_… or a service_role JWT. */
function isSecretKey(key: string) {
  if (key.startsWith('sb_secret_')) return true
  try {
    return JSON.parse(Buffer.from(key.split('.')[1] ?? '', 'base64url').toString()).role === 'service_role'
  } catch {
    return false
  }
}

/**
 * Production Content-Security-Policy, written into index.html at build time so
 * it names the exact Supabase project (REST, storage, edge functions and the
 * realtime socket) and works on Vercel or any other static host.
 */
function contentSecurityPolicy(supabaseUrl: string): Plugin {
  const api = new URL(supabaseUrl).origin
  const socket = api.replace(/^http/, 'ws')
  const policy = [
    "default-src 'self'",
    "script-src 'self'",
    // Motion, Leaflet and Recharts position elements with inline styles.
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    // Supabase storage (avatars, logos, product photos), map tiles, Google profile photos, local previews.
    `img-src 'self' data: blob: ${api} https://*.tile.openstreetmap.org https://*.googleusercontent.com`,
    `connect-src 'self' ${api} ${socket}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    ...(api.startsWith('https:') ? ['upgrade-insecure-requests'] : []),
  ].join('; ')
  return {
    name: 'aerodrop-csp',
    apply: 'build',
    transformIndexHtml: () => [{ tag: 'meta', attrs: { 'http-equiv': 'Content-Security-Policy', content: policy }, injectTo: 'head-prepend' }],
  }
}

/**
 * The first non-empty value among the given names. Accepts the names Vercel's
 * Supabase integration creates (NEXT_PUBLIC_SUPABASE_*, SUPABASE_*) as well as
 * our own VITE_* ones. Only public values are listed: the integration's
 * SUPABASE_SERVICE_ROLE_KEY and SUPABASE_JWT_SECRET are never read.
 */
const pick = (env: Record<string, string | undefined>, names: string[]) => names.map((n) => env[n]?.trim()).find(Boolean) ?? ''

export default defineConfig(({ command, mode }) => {
  const env: Record<string, string | undefined> = { ...loadEnv(mode, import.meta.dirname, ''), ...process.env }
  const supabaseUrl = pick(env, ['VITE_SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_URL', 'SUPABASE_URL'])
  const supabaseKey = pick(env, [
    'VITE_SUPABASE_ANON_KEY',
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'SUPABASE_PUBLISHABLE_KEY',
    'SUPABASE_ANON_KEY',
  ])
  const plugins: PluginOption[] = [react(), tailwindcss()]

  // A production build must point at the app's Supabase project, with the public key.
  if (command === 'build') {
    const missing = [!supabaseUrl && 'VITE_SUPABASE_URL', !supabaseKey && 'VITE_SUPABASE_ANON_KEY'].filter(Boolean)
    if (missing.length) throw new Error(`Missing ${missing.join(' and ')}. Set them in .env locally, or in Vercel → Project → Settings → Environment Variables (the Supabase integration's NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY also work) for this environment, then redeploy.`)
    if (isSecretKey(supabaseKey)) throw new Error('The Supabase key is a secret key. Use the publishable (sb_publishable_…) or anon key; a secret key would be shipped to every visitor.')
    if (!env.VITE_PLAY_STORE_URL) console.warn('[aerodrop] VITE_PLAY_STORE_URL is not set: Google Play buttons will be hidden.')
    console.log(`[aerodrop] Supabase project: ${new URL(supabaseUrl).host}`)
    plugins.push(contentSecurityPolicy(supabaseUrl))
  }

  return {
    plugins,
    resolve: { alias: { '@': path.resolve(import.meta.dirname, 'src') } },
    // The app code reads import.meta.env.VITE_SUPABASE_*; fill them from whichever name was set.
    define: {
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(supabaseUrl),
      'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(supabaseKey),
    },
  }
})
