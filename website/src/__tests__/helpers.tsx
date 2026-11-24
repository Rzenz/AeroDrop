import { render } from '@testing-library/react'
import type { ReactElement } from 'react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi } from 'vitest'
import { Toaster } from '@/components/ui/toast'
import type { Profile } from '@/types'

/** Renders a page inside the router at [path]. */
export const renderPage = (page: ReactElement, path = '/') => render(
    <MemoryRouter initialEntries={[path]}>
      {page}
      <Toaster />
    </MemoryRouter>,
  )

/** Renders a page under a route pattern such as /user/products/:id, so useParams works. */
export const renderRoute = (page: ReactElement, pattern: string, path: string) =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path={pattern} element={page} />
        <Route path="*" element={<p>Navigated away</p>} />
      </Routes>
      <Toaster />
    </MemoryRouter>,
  )

/**
 * A stand-in for the Supabase-backed api: every call resolves to [] unless a
 * test sets it, so pages load without a network.
 */
export function fakeApi(overrides: Record<string, unknown> = {}) {
  const fns: Record<string, unknown> = { ...overrides }
  return new Proxy(fns, { get: (t, k: string) => (t[k] ??= vi.fn(async () => [])) })
}

export const profile = (p: Partial<Profile>): Profile => ({
  id: 'u1', email: 'maria.santos@uclm.edu.ph', full_name: 'Maria Santos', phone_number: '+639171234567', role: 'user', account_status: 'active',
  vendor_status: null, business_name: null, business_category: null, business_description: null, business_logo_url: null, avatar_url: null,
  campus_location_id: null, created_at: '2026-10-08T08:00:00Z', email_verified_at: '2026-10-08T08:00:00Z', ...p,
})
