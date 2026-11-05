import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ command, mode }) => {
  const env = { ...loadEnv(mode, import.meta.dirname, 'VITE_'), ...process.env }
  // A production build must point at the app's Supabase project.
  if (command === 'build') {
    const missing = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY'].filter((k) => !env[k])
    if (missing.length) throw new Error(`Missing ${missing.join(' and ')}. Copy .env.example to .env and fill in the app's Supabase project.`)
    const key = String(env.VITE_SUPABASE_ANON_KEY)
    let role = ''
    try { role = JSON.parse(Buffer.from(key.split('.')[1] ?? '', 'base64url').toString()).role } catch { /* not a JWT */ }
    if (key.startsWith('sb_secret_') || role === 'service_role') throw new Error('VITE_SUPABASE_ANON_KEY is a secret key. Use the publishable (sb_publishable_…) or anon key; a secret key would be shipped to every visitor.')
    if (!env.VITE_PLAY_STORE_URL) console.warn('[aerodrop] VITE_PLAY_STORE_URL is not set: Google Play buttons will be hidden.')
  }
  return {
    plugins: [react(), tailwindcss()],
    resolve: { alias: { '@': path.resolve(import.meta.dirname, 'src') } },
  }
})
