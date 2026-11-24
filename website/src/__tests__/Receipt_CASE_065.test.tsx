import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Receipt from '@/pages/user/receipt'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  const o = f.order('h1', 'canteen', 'UCLM Canteen', [['adobo', 1]], 'delivered', { delivery: f.delivery('h1', { status: 'delivered', progress: 1 }) })
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ order: vi.fn(async () => o), locations: vi.fn(async () => f.locations) }) }
})

describe('Test Case ID: CASE-065', () => {
  test(
    'Test Case Description: Customer opens the receipt of a delivered UCLM Canteen order (Chicken Adobo Rice P95.00 + P23.19 delivery fee) | ' +
      'Expected Result: Receipt lists the item, the delivery fee and a total of P118.19',
    async () => {
      renderRoute(<Receipt />, '/user/orders/:id/receipt', '/user/orders/h1/receipt')

      expect(await screen.findByText('Chicken Adobo Rice', {}, { timeout: 4000 })).toBeInTheDocument()
      expect(screen.getAllByText('₱23.19').length).toBeGreaterThan(0)
      expect(screen.getAllByText('₱118.19').length).toBeGreaterThan(0)
      expect(screen.getByText('UCLM Canteen')).toBeInTheDocument()
    },
  )
})
