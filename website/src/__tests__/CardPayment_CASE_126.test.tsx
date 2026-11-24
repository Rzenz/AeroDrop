import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Checkout from '@/pages/user/checkout'
import { api } from '@/data/api'
import { addToCart, cartStore } from '@/lib/cart'
import { products } from './fixtures'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations), weather: vi.fn(async () => f.weather), deliveryZone: vi.fn(async () => null), placeOrder: vi.fn(async () => 'o-paid'), quoteOrderFee: vi.fn(async () => ({ subtotal: 120, deliveryFee: 27.19, totalAmount: 147.19, totalWeightGrams: 380, tripsRequired: 1, distanceKm: 0.2097, isCaution: false, breakdown: { base: 15, distance: 8.39, weight: 3.8, extraTrip: 0, weather: 0 } })) }) } })

describe('Test Case ID: CASE-126', () => {
  test(
    'Test Case Description: Customer pays P147.19 with Simulated Card using a valid card number (4111 1111 1111 1111) on the website | ' +
      "Expected Result: The order is placed and 'Order placed. The vendor will confirm it shortly.' is shown",
    async () => {
      cartStore.set([])
      addToCart(products[0], 'Kape Kanto')
      renderPage(<Checkout />, '/user/checkout')
      await screen.findAllByText('₱147.19', {}, { timeout: 3000 })
      fireEvent.click(screen.getByText('Simulated Card'))
      fireEvent.change(screen.getByLabelText('Card number'), { target: { value: '4111 1111 1111 1111' } })
      fireEvent.change(screen.getByLabelText('Expiry'), { target: { value: '12/28' } })
      fireEvent.change(screen.getByLabelText('CVC'), { target: { value: '123' } })
      fireEvent.click(screen.getByRole('button', { name: 'Place order' }))

      await vi.waitFor(() => expect(api.placeOrder).toHaveBeenCalledTimes(1))
      expect(await screen.findByText('Order placed. The vendor will confirm it shortly.')).toBeInTheDocument()
      expect(screen.queryByText('That card number is not valid.')).not.toBeInTheDocument()
    },
  )
})
