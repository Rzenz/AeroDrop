import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Shop from '@/pages/user/shop'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ vendors: vi.fn(async () => f.vendors), products: vi.fn(async () => f.products), locations: vi.fn(async () => f.locations) }) }
})

describe('Test Case ID: CASE-056', () => {
  test(
    'Test Case Description: Customer searches the Shop for "tea" | ' +
      'Expected Result: Only Tea Haus and its tea products are listed',
    async () => {
      renderPage(<Shop />, '/user/shop')
      expect(await screen.findByText('Kape Kanto')).toBeInTheDocument()

      fireEvent.change(screen.getByLabelText('Search vendors and products'), { target: { value: 'tea' } })

      expect(screen.getByText('Tea Haus')).toBeInTheDocument()
      expect(screen.getByText('Classic Milk Tea')).toBeInTheDocument()
      expect(screen.getByText('Mango Fruit Tea')).toBeInTheDocument()
      expect(screen.queryByText('Kape Kanto')).not.toBeInTheDocument()
      expect(screen.queryByText('Campus Mart')).not.toBeInTheDocument()
    },
  )
})
