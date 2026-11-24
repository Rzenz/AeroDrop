import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import OrderDetail from '@/pages/shared/order-detail'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
// The vendor_mark_order_ready server function refuses to dispatch while the weather is grounded.
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => f.order('o1', 'kape', 'Kape Kanto', [['americano', 1]], 'preparing', { user_id: 'paolo', customer_name: 'Paolo Reyes', delivery_location_id: 'annex2' })), locations: vi.fn(async () => f.locations), messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => null), subscribeMessages: vi.fn(() => () => {}), markOrderReady: vi.fn(async () => { throw new Error('Flight dispatch blocked: Weather is grounded') }) }) } })

describe('Test Case ID: CASE-104', () => {
  test(
    'Test Case Description: Kape Kanto marks an order ready for drone pickup on the website while the campus weather is GROUNDED | ' +
      "Expected Result: No drone is dispatched and 'Flight dispatch blocked: Weather is grounded' is shown",
    async () => {
      renderRoute(<OrderDetail />, '/vendor/orders/:id', '/vendor/orders/o1')

      fireEvent.click(await screen.findByRole('button', { name: 'Ready for drone pickup' }))

      await vi.waitFor(() => expect(api.markOrderReady).toHaveBeenCalledWith('o1'))
      expect(await screen.findByText('Flight dispatch blocked: Weather is grounded')).toBeInTheDocument()
      expect(screen.queryByText('Ready for drone pickup.')).not.toBeInTheDocument()
    },
  )
})
