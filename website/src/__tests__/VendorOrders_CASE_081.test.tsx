import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import OrderDetail from '@/pages/shared/order-detail'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => f.order('o1', 'kape', 'Kape Kanto', [['americano', 1], ['croissant', 1]], 'pending', { user_id: 'paolo', customer_name: 'Paolo Reyes', delivery_location_id: 'annex2' })), locations: vi.fn(async () => f.locations), messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => null), setOrderStatus: vi.fn(async () => undefined), subscribeMessages: vi.fn(() => () => {}) }) } })

describe('Test Case ID: CASE-081', () => {
  test(
    "Test Case Description: Vendor rejects Paolo Reyes's pending order | " +
      'Expected Result: A "Reject this order?" confirmation appears and confirming sets the order to rejected',
    async () => {
      renderRoute(<OrderDetail />, '/vendor/orders/:id', '/vendor/orders/o1')

      expect(await screen.findByRole('button', { name: 'Confirm' })).toBeInTheDocument()
      fireEvent.click(screen.getByRole('button', { name: 'Reject' }))
      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Reject this order?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Reject order' }))

      await vi.waitFor(() => expect(api.setOrderStatus).toHaveBeenCalledWith('o1', 'rejected'))
    },
  )
})
