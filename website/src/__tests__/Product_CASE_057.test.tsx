import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import ProductPage from '@/pages/user/product'
import { renderRoute } from './helpers'

vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ product: vi.fn(async () => f.products.find((p) => p.id === 'mango')), vendors: vi.fn(async () => f.vendors) }) }
})

describe('Test Case ID: CASE-057', () => {
  test(
    'Test Case Description: Customer opens Mango Fruit Tea, which has 0 stock | ' +
      'Expected Result: Product is marked Sold out and the Add to cart button is disabled',
    async () => {
      renderRoute(<ProductPage />, '/user/products/:id', '/user/products/mango')

      expect(await screen.findByText('Mango Fruit Tea')).toBeInTheDocument()
      expect(screen.getByText('Sold out')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /Add to cart/ })).toBeDisabled()
    },
  )
})
