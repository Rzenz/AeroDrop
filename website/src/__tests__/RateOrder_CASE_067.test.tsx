import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import OrderDetail from '@/pages/shared/order-detail'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => f.order('h1', 'canteen', 'UCLM Canteen', [['adobo', 1]], 'delivered', { delivery: f.delivery('h1', { status: 'delivered', progress: 1 }) })), locations: vi.fn(async () => f.locations), orderReviews: vi.fn(async () => null), messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => null), subscribeMessages: vi.fn(() => () => {}) }) } })

describe('Test Case ID: CASE-067', () => {
  test(
    'Test Case Description: Customer opens Rate this order on a delivered UCLM Canteen order and submits without any stars | ' +
      "Expected Result: The review is not sent and 'Rate the store or at least one product.' is shown",
    async () => {
      renderRoute(<OrderDetail />, '/user/orders/:id', '/user/orders/h1')
      fireEvent.click(await screen.findByRole('button', { name: /Rate this order/ }))

      const dialog = await screen.findByRole('dialog')
      fireEvent.click(within(dialog).getByRole('button', { name: 'Submit review' }))

      expect(await within(dialog).findByText('Rate the store or at least one product.')).toBeInTheDocument()
      expect(api.submitReview).not.toHaveBeenCalled()
    },
  )
})
