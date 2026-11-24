import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Checkout from '@/pages/user/checkout'
import { addToCart, cartStore } from '@/lib/cart'
import { products } from './fixtures'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
// The quote is what quote_order_fee() returns for 1 x Iced Spanish Latte from Kape Kanto (Main Building) to the Maritime Building.
vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return {
    ...(await import('@/data/auth-errors')),
    api: (await import('./helpers')).fakeApi({
      locations: vi.fn(async () => f.locations),
      weather: vi.fn(async () => f.weather),
      deliveryZone: vi.fn(async () => null),
      quoteOrderFee: vi.fn(async () => ({ subtotal: 120, deliveryFee: 27.19, totalAmount: 147.19, totalWeightGrams: 380, tripsRequired: 1, distanceKm: 0.2097, isCaution: false, breakdown: { base: 15, distance: 8.39, weight: 3.8, extraTrip: 0, weather: 0 } })),
    }),
  }
})

describe('Test Case ID: CASE-061', () => {
  test(
    'Test Case Description: Customer checks out 1 x Iced Spanish Latte (P120.00) for delivery to the Maritime Building | ' +
      'Expected Result: Order summary shows the delivery fee breakdown (Base P15.00, Distance P8.39, Weight P3.80) and a total of P147.19',
    async () => {
      cartStore.set([])
      addToCart(products[0], 'Kape Kanto')
      renderPage(<Checkout />, '/user/checkout')

      expect((await screen.findAllByText('₱147.19', {}, { timeout: 3000 })).length).toBeGreaterThan(0)
      expect(screen.getAllByText('₱15.00').length).toBeGreaterThan(0)
      expect(screen.getAllByText('₱8.39').length).toBeGreaterThan(0)
      expect(screen.getAllByText('₱3.80').length).toBeGreaterThan(0)
      expect(screen.getByRole('button', { name: 'Place order' })).toBeEnabled()
    },
  )
})
