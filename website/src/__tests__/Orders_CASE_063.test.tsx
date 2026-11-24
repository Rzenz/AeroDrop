import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import UserOrders from '@/pages/user/orders'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const { order, delivery } = await import('./fixtures')
  const orders = [
    order('live', 'kape', 'Kape Kanto', [['latte', 1]], 'in_transit', { delivery: delivery('live') }),
    order('prep', 'tea', 'Tea Haus', [['classic', 1]], 'preparing'),
    order('h1', 'canteen', 'UCLM Canteen', [['adobo', 1]], 'delivered', { delivery: delivery('h1', { status: 'delivered', progress: 1 }) }),
    order('h2', 'mart', 'Campus Mart', [['pad', 2]], 'delivered', { delivery: delivery('h2', { status: 'delivered', progress: 1 }) }),
    order('h3', 'kape', 'Kape Kanto', [['croissant', 2]], 'cancelled'),
  ]
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ orders: vi.fn(async () => orders) }) }
})

describe('Test Case ID: CASE-063', () => {
  test(
    'Test Case Description: Customer opens My Orders and selects the Delivered tab | ' +
      'Expected Result: Only delivered orders (UCLM Canteen, Campus Mart) are listed',
    async () => {
      renderPage(<UserOrders />, '/user/orders')
      expect(await screen.findByText('Tea Haus')).toBeInTheDocument()

      fireEvent.click(screen.getByRole('tab', { name: /Delivered/ }))

      expect(screen.getByText('UCLM Canteen')).toBeInTheDocument()
      expect(screen.getByText('Campus Mart')).toBeInTheDocument()
      expect(screen.queryByText('Tea Haus')).not.toBeInTheDocument()
      expect(screen.queryByText('Kape Kanto')).not.toBeInTheDocument()
    },
  )
})
