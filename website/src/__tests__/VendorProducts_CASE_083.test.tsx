import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import VendorProducts from '@/pages/vendor/products'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ products: vi.fn(async () => f.products.filter((p) => p.vendor_id === 'kape')) }) } })

describe('Test Case ID: CASE-083', () => {
  test(
    'Test Case Description: Vendor searches their product list for "latte" | ' +
      'Expected Result: Only Iced Spanish Latte is listed',
    async () => {
      renderPage(<VendorProducts />, '/vendor/products')
      expect(await screen.findByText('Americano')).toBeInTheDocument()

      fireEvent.change(screen.getByLabelText('Search products'), { target: { value: 'latte' } })

      expect(screen.getByText('Iced Spanish Latte')).toBeInTheDocument()
      expect(screen.queryByText('Americano')).not.toBeInTheDocument()
      expect(screen.queryByText('Butter Croissant')).not.toBeInTheDocument()
    },
  )
})
