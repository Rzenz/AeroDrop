import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminDeliveries from '@/pages/admin/deliveries'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ orders: vi.fn(async () => [f.order('live', 'kape', 'Kape Kanto', [['latte', 1]], 'in_transit', { delivery: f.delivery('live') }), f.order('h1', 'canteen', 'UCLM Canteen', [['adobo', 1]], 'delivered', { delivery: f.delivery('h1', { status: 'delivered', progress: 1 }) })]) }) } })

describe('Test Case ID: CASE-139', () => {
  test(
    'Test Case Description: Admin searches all deliveries for "Pizza Corner", a store with no orders | ' +
      "Expected Result: No delivery is listed and 'No deliveries here' with 'Try another search.' is shown",
    async () => {
      renderPage(<AdminDeliveries />, '/admin/deliveries')
      expect(await screen.findByText('Kape Kanto')).toBeInTheDocument()
      fireEvent.change(screen.getByLabelText('Search orders'), { target: { value: 'Pizza Corner' } })

      expect(screen.getByText('No deliveries here')).toBeInTheDocument()
      expect(screen.getByText('Try another search.')).toBeInTheDocument()
      expect(screen.queryByText('Kape Kanto')).not.toBeInTheDocument()
    },
  )
})
