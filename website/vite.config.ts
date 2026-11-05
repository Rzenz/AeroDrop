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

export default defineConfig(({ command, mode }) => {
  const env = { ...loadEnv(mode, import.meta.dirname, 'VITE_'), ...process.env }
  const plugins: PluginOption[] = [react(), tailwindcss()]

  // A production build must point at the app's Supabase project, with the public key.
  if (command === 'build') {
    const missing = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY'].filter((k) => !env[k])
    if (missing.length) throw new Error(`Missing ${missing.join(' and ')}. Set them in .env locally, or in Vercel → Project → Settings → Environment Variables.`)
    if (isSecretKey(String(env.VITE_SUPABASE_ANON_KEY))) throw new Error('VITE_SUPABASE_ANON_KEY is a secret key. Use the publishable (sb_publishable_…) or anon key; a secret key would be shipped to every visitor.')
    if (!env.VITE_PLAY_STORE_URL) console.warn('[aerodrop] VITE_PLAY_STORE_URL is not set: Google Play buttons will be hidden.')
    plugins.push(contentSecurityPolicy(String(env.VITE_SUPABASE_URL)))
  }

  return {
    plugins,
    resolve: { alias: { '@': path.resolve(import.meta.dirname, 'src') } },
  }
})
