import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'

const root = createRoot(document.getElementById('root')!)
const key = String(import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim()
const configured = Boolean(import.meta.env.VITE_SUPABASE_URL && key)

/** True for keys that must never reach a browser: sb_secret_… or a service_role JWT. */
function isSecretKey(k: string) {
  if (k.startsWith('sb_secret_')) return true
  try {
    return JSON.parse(atob(k.split('.')[1]!.replace(/-/g, '+').replace(/_/g, '/'))).role === 'service_role'
  } catch {
    return false
  }
}

if (configured && isSecretKey(key)) {
  root.render(
    <main className="grid min-h-dvh place-items-center bg-bg px-4 text-ink">
      <div className="w-full max-w-lg rounded-2xl bg-surface p-6 shadow-md">
        <img src="/img/brand-mark.png" alt="" width={40} height={40} className="size-10 rounded-xl" />
        <h1 className="mt-4 font-display text-2xl font-extrabold">Wrong Supabase key</h1>
        <p className="mt-2 text-ink-2">
          <code className="font-mono text-sm">VITE_SUPABASE_ANON_KEY</code> holds a secret key, which bypasses every security rule and must never be used in a website. Replace it with the
          publishable key (<code className="font-mono text-sm">sb_publishable_…</code>) or the legacy <code className="font-mono text-sm">anon</code> key, then restart{' '}
          <code className="font-mono text-sm">npm run dev</code>.
        </p>
        <p className="mt-3 text-sm text-ink-3">Supabase dashboard → Project Settings → API Keys.</p>
      </div>
    </main>,
  )
} else if (configured) {
  // The app (and its Supabase client) only loads once the connection is configured.
  import('./App').then(({ default: App }) =>
    root.render(
      <StrictMode>
        <App />
      </StrictMode>,
    ),
  )
} else {
  // Without the app's Supabase project there is nothing to show; say why
  // instead of leaving a blank page.
  root.render(
    <main className="grid min-h-dvh place-items-center bg-bg px-4 text-ink">
      <div className="w-full max-w-lg rounded-2xl bg-surface p-6 shadow-md">
        <img src="/img/brand-mark.png" alt="" width={40} height={40} className="size-10 rounded-xl" />
        <h1 className="mt-4 font-display text-2xl font-extrabold">AeroDrop isn’t connected yet</h1>
        <p className="mt-2 text-ink-2">
          Add the Supabase project the AeroDrop app uses to <code className="font-mono text-sm">website/.env</code>, then restart <code className="font-mono text-sm">npm run dev</code>.
        </p>
        <pre className="mt-4 overflow-x-auto rounded-xl bg-sunken p-4 font-mono text-sm text-ink">
          {'VITE_SUPABASE_URL=https://<project-ref>.supabase.co\nVITE_SUPABASE_ANON_KEY=<anon key>'}
        </pre>
        <p className="mt-3 text-sm text-ink-3">Supabase dashboard → Project Settings → API.</p>
      </div>
    </main>,
  )
}
