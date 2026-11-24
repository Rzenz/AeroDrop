import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Checkout from '@/pages/user/checkout'
import { api } from '@/data/api'
import { addToCart, cartStore } from '@/lib/cart'
import { products } from './fixtures'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph', campus_location_id: 'annex2', email_verified_at: null })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  return {
    ...(await import('@/data/auth-errors')),
    api: (await import('./helpers')).fakeApi({
      locations: vi.fn(async () => f.locations),
      weather: vi.fn(async () => f.weather),
      deliveryZone: vi.fn(async () => null),
      quoteOrderFee: vi.fn(async () => ({ subtotal: 120, deliveryFee: 21.92, totalAmount: 141.92, totalWeightGrams: 380, tripsRequired: 1, distanceKm: 0.0779, isCaution: false, breakdown: { base: 15, distance: 3.12, weight: 3.8, extraTrip: 0, weather: 0 } })),
    }),
  }
})

describe('Test Case ID: CASE-062', () => {
  test(
    'Test Case Description: Customer whose email is not yet verified tries to check out | ' +
      'Expected Result: Checkout asks the customer to verify their email and the Place order button is disabled',
    async () => {
      cartStore.set([])
      addToCart(products[0], 'Kape Kanto')
      renderPage(<Checkout />, '/user/checkout')

      expect(await screen.findByText('Verify your email to place this order.', {}, { timeout: 3000 })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Place order' })).toBeDisabled()
      expect(api.placeOrder).not.toHaveBeenCalled()
    },
  )
})
