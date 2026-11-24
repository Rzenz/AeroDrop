import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import VendorDashboard from '@/pages/vendor/dashboard'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', business_category: 'Cafe', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ orders: vi.fn(async () => [f.order('o1', 'kape', 'Kape Kanto', [['americano', 1]], 'pending', { customer_name: 'Paolo Reyes' }), f.order('a', 'kape', 'Kape Kanto', [['latte', 1]], 'delivered'), f.order('b', 'kape', 'Kape Kanto', [['latte', 2]], 'delivered')]), products: vi.fn(async () => f.products.filter((p) => p.vendor_id === 'kape')), weather: vi.fn(async () => f.weather) }) } })

describe('Test Case ID: CASE-079', () => {
  test(
    'Test Case Description: Kape Kanto opens the vendor Store Performance dashboard | ' +
      'Expected Result: The pending order count and the Total Gross Revenue of delivered orders are shown',
    async () => {
      renderPage(<VendorDashboard />, '/vendor')

      expect(await screen.findByText('Total Gross Revenue')).toBeInTheDocument()
      expect(screen.getAllByText('₱360.00').length).toBeGreaterThan(0)
      expect(screen.getByLabelText('Orders needing action')).toHaveTextContent(/Pending\s*1/)
    },
  )
})
