import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import VendorProducts from '@/pages/vendor/products'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ products: vi.fn(async () => f.products.filter((p) => p.vendor_id === 'kape')) }) } })

describe('Test Case ID: CASE-134', () => {
  test(
    'Test Case Description: Vendor searches their product list for "matcha", which they do not sell | ' +
      "Expected Result: No product is listed and 'No products match' is shown",
    async () => {
      renderPage(<VendorProducts />, '/vendor/products')
      expect(await screen.findByText('Americano')).toBeInTheDocument()
      fireEvent.change(screen.getByLabelText('Search products'), { target: { value: 'matcha' } })

      expect(screen.getByText('No products match')).toBeInTheDocument()
      expect(screen.queryByText('Americano')).not.toBeInTheDocument()
      expect(screen.queryByText('Iced Spanish Latte')).not.toBeInTheDocument()
    },
  )
})
