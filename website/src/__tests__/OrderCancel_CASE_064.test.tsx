import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import OrderDetail from '@/pages/shared/order-detail'
import { api } from '@/data/api'
import { order } from './fixtures'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => f.order('prep', 'tea', 'Tea Haus', [['classic', 1]], 'preparing')), locations: vi.fn(async () => f.locations), orderReviews: vi.fn(async () => null), messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => null), cancelOrder: vi.fn(async () => undefined), subscribeMessages: vi.fn(() => () => {}) }) }
})
void order

describe('Test Case ID: CASE-064', () => {
  test(
    'Test Case Description: Customer cancels an order that Tea Haus is still preparing | ' +
      'Expected Result: A "Cancel this order?" confirmation appears and confirming cancels the order',
    async () => {
      renderRoute(<OrderDetail />, '/user/orders/:id', '/user/orders/prep')

      fireEvent.click(await screen.findByRole('button', { name: 'Cancel order' }))
      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Cancel this order?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Cancel order' }))

      await vi.waitFor(() => expect(api.cancelOrder).toHaveBeenCalledWith('prep'))
    },
  )
})
