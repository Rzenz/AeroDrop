import { screen, within } from '@testing-library/react'
import { describe, expect, test } from 'vitest'
import Cart from '@/pages/user/cart'
import { addToCart, cartCount, cartStore } from '@/lib/cart'
import type { Product } from '@/types'
import { renderPage } from './helpers'

const product = (id: string, name: string, price: number, weight_grams: number): Product => ({
  id, vendor_id: 'kape', name, description: null, price, stock_quantity: 20, category: null, weight_grams, image_url: null, is_active: true, created_at: '2026-10-08T08:00:00Z',
})

describe('Test Case ID: CASE-059', () => {
  test(
    'Test Case Description: User adds Iced Spanish Latte (P120) and Butter Croissant (P65) to the cart on the website | ' +
      'Expected Result: Cart lists both items under Kape Kanto, 0.47 kg in 1 trip, with a subtotal of P185.00',
    () => {
      cartStore.set([])
      addToCart(product('latte', 'Iced Spanish Latte', 120, 380), 'Kape Kanto')
      addToCart(product('croissant', 'Butter Croissant', 65, 90), 'Kape Kanto')
      expect(cartCount(cartStore.get())).toBe(2)

      renderPage(<Cart />, '/user/cart')
      expect(screen.getByText('Kape Kanto')).toBeInTheDocument()
      expect(screen.getByText('Iced Spanish Latte')).toBeInTheDocument()
      expect(screen.getByText('Butter Croissant')).toBeInTheDocument()
      expect(screen.getByText('0.47 kg · 1 trip')).toBeInTheDocument()
      const summary = screen.getByText('Summary').closest('div')!.parentElement!
      expect(within(summary).getByText('₱185.00')).toBeInTheDocument()
    },
  )
})
