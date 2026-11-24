import { screen } from '@testing-library/react'
import { describe, expect, test } from 'vitest'
import Cart from '@/pages/user/cart'
import { addToCart, cartStore } from '@/lib/cart'
import { tripsForWeight } from '@/lib/fees'
import type { Product } from '@/types'
import { renderPage } from './helpers'

const latte: Product = {
  id: 'latte', vendor_id: 'kape', name: 'Iced Spanish Latte', description: null, price: 120, stock_quantity: 24, category: 'Coffee', weight_grams: 380, image_url: null, is_active: true, created_at: '2026-10-08T08:00:00Z',
}

describe('Test Case ID: CASE-060', () => {
  test(
    'Test Case Description: User puts 3 x Iced Spanish Latte (1.14 kg) in the cart on the website | ' +
      'Expected Result: Cart shows 3 trips and blocks the order as too heavy (limit 2 trips, 1.0 kg)',
    () => {
      expect(tripsForWeight(1.14)).toBe(3)
      cartStore.set([])
      addToCart(latte, 'Kape Kanto', 3)

      renderPage(<Cart />, '/user/cart')
      expect(screen.getByText('1.14 kg · 3 trips')).toBeInTheDocument()
      expect(screen.getByText('Too heavy for one order. The limit is 2 trips (1.0 kg). Remove some items or split it.')).toBeInTheDocument()
    },
  )
})
