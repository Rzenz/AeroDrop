import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import OrderDetail from '@/pages/shared/order-detail'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => f.order('h1', 'canteen', 'UCLM Canteen', [['adobo', 1]], 'delivered', { delivery: f.delivery('h1', { status: 'delivered', progress: 1 }) })), locations: vi.fn(async () => f.locations), orderReviews: vi.fn(async () => null), messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => null), subscribeMessages: vi.fn(() => () => {}), submitReview: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-127', () => {
  test(
    'Test Case Description: Customer gives UCLM Canteen 5 stars in Rate this order on a delivered order and clicks Submit review | ' +
      "Expected Result: The review is sent and 'Thanks for the review.' is shown",
    async () => {
      renderRoute(<OrderDetail />, '/user/orders/:id', '/user/orders/h1')
      fireEvent.click(await screen.findByRole('button', { name: /Rate this order/ }))
      const dialog = await screen.findByRole('dialog')
      fireEvent.click(within(within(dialog).getByRole('group', { name: 'Store rating' })).getByLabelText('5 stars'))
      fireEvent.click(within(dialog).getByRole('button', { name: 'Submit review' }))

      await vi.waitFor(() => expect(api.submitReview).toHaveBeenCalledTimes(1))
      expect(vi.mocked(api.submitReview).mock.calls[0]![0]).toBe('h1')
      expect(await screen.findByText('Thanks for the review.')).toBeInTheDocument()
    },
  )
})
