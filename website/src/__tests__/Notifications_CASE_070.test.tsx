import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Notifications from '@/pages/shared/notifications'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => {
  const { notification } = await import('./fixtures')
  const list = [
    notification('n1', 'Drone dispatched', 'Your order from Kape Kanto is on its way.', 'drone_dispatched', false, { order_id: 'live' }),
    notification('n2', 'Order is being prepared', 'Tea Haus is preparing your Classic Milk Tea.', 'order_preparing', false, { order_id: 'prep' }),
    notification('n3', 'Order delivered', 'Your package has arrived at UCLM Maritime Building.', 'order_delivered', true, { order_id: 'h1' }),
  ]
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ notifications: vi.fn(async () => list) }) }
})

describe('Test Case ID: CASE-070', () => {
  test(
    'Test Case Description: Customer opens Notifications and selects the Unread tab | ' +
      'Expected Result: Unread count is 2 and only the 2 unread notifications are listed',
    async () => {
      renderPage(<Notifications />, '/user/notifications')
      expect(await screen.findByText('Order delivered')).toBeInTheDocument()

      const unreadTab = screen.getByRole('tab', { name: /Unread/ })
      expect(unreadTab).toHaveTextContent('2')
      fireEvent.click(unreadTab)

      expect(screen.getByText('Drone dispatched')).toBeInTheDocument()
      expect(screen.getByText('Order is being prepared')).toBeInTheDocument()
      expect(screen.queryByText('Order delivered')).not.toBeInTheDocument()
    },
  )
})
