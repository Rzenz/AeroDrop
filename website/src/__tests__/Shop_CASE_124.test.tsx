import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Shop from '@/pages/user/shop'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ vendors: vi.fn(async () => f.vendors), products: vi.fn(async () => f.products), locations: vi.fn(async () => f.locations) }) }
})

describe('Test Case ID: CASE-124', () => {
  test(
    'Test Case Description: Customer searches the Shop for "pizza", which no store sells | ' +
      "Expected Result: No vendor or product is listed and 'No matches' is shown",
    async () => {
      renderPage(<Shop />, '/user/shop')
      expect(await screen.findByText('Kape Kanto')).toBeInTheDocument()
      fireEvent.change(screen.getByLabelText('Search vendors and products'), { target: { value: 'pizza' } })

      expect(screen.getByText('No matches')).toBeInTheDocument()
      expect(screen.queryByText('Kape Kanto')).not.toBeInTheDocument()
      expect(screen.queryByText('Tea Haus')).not.toBeInTheDocument()
    },
  )
})
