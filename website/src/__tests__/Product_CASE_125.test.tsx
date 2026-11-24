import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import ProductPage from '@/pages/user/product'
import { renderRoute } from './helpers'

vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ product: vi.fn(async () => f.products.find((p) => p.id === 'latte')), vendors: vi.fn(async () => f.vendors) }) }
})

describe('Test Case ID: CASE-125', () => {
  test(
    'Test Case Description: Customer opens Iced Spanish Latte, which is in stock, and clicks Add to cart | ' +
      "Expected Result: The product is added and '1 × Iced Spanish Latte added to cart.' is shown",
    async () => {
      renderRoute(<ProductPage />, '/user/products/:id', '/user/products/latte')
      expect(await screen.findByText('Iced Spanish Latte')).toBeInTheDocument()
      const add = screen.getByRole('button', { name: /Add to cart/ })
      expect(add).toBeEnabled()
      fireEvent.click(add)

      expect(await screen.findByText('1 × Iced Spanish Latte added to cart.')).toBeInTheDocument()
    },
  )
})
