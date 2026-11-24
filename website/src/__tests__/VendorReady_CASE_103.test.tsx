import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import OrderDetail from '@/pages/shared/order-detail'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => f.order('o1', 'kape', 'Kape Kanto', [['americano', 1]], 'preparing', { user_id: 'paolo', customer_name: 'Paolo Reyes', delivery_location_id: 'annex2' })), locations: vi.fn(async () => f.locations), messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => null), subscribeMessages: vi.fn(() => () => {}), markOrderReady: vi.fn(async () => 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.') }) } })

describe('Test Case ID: CASE-103', () => {
  test(
    "Test Case Description: Kape Kanto marks Paolo Reyes's order that is being prepared as ready for drone pickup | " +
      "Expected Result: A drone is dispatched and 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.' is shown",
    async () => {
      renderRoute(<OrderDetail />, '/vendor/orders/:id', '/vendor/orders/o1')

      fireEvent.click(await screen.findByRole('button', { name: 'Ready for drone pickup' }))

      await vi.waitFor(() => expect(api.markOrderReady).toHaveBeenCalledWith('o1'))
      expect(await screen.findByText('Order is ready for delivery. Drone DRN-001 dispatched for pickup.')).toBeInTheDocument()
    },
  )
})
