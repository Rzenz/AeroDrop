import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import VendorPage from '@/pages/user/vendor'
import { renderRoute } from './helpers'

vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return {
    ...(await import('@/data/auth-errors')),
    api: (await import('./helpers')).fakeApi({
      vendors: vi.fn(async () => f.vendors),
      products: vi.fn(async () => f.products.filter((p) => p.vendor_id === 'kape')),
      locations: vi.fn(async () => f.locations),
      vendorReviews: vi.fn(async () => [{ id: 'r1', rating: 5, comment: 'Arrived cold and fast. The drone landing was fun to watch.', reviewer_name: 'Maria S.', created_at: f.NOW }]),
    }),
  }
})

describe('Test Case ID: CASE-058', () => {
  test(
    'Test Case Description: Customer opens the Kape Kanto store page | ' +
      'Expected Result: Store shows its rating (4.7, 38 reviews), pickup building, menu and customer reviews',
    async () => {
      renderRoute(<VendorPage />, '/user/vendors/:id', '/user/vendors/kape')

      expect(await screen.findByRole('heading', { name: 'Kape Kanto' })).toBeInTheDocument()
      expect(screen.getAllByText('4.7').length).toBeGreaterThan(0)
      expect(screen.getByText(/Picks up at UCLM Main Building/)).toBeInTheDocument()
      expect(await screen.findByText('Iced Spanish Latte')).toBeInTheDocument()
      expect(await screen.findByText('Arrived cold and fast. The drone landing was fun to watch.')).toBeInTheDocument()
    },
  )
})
