import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Track from '@/pages/user/track'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/components/campus-map', () => ({ CampusMap: () => null }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ orders: vi.fn(async () => [f.order('live', 'kape', 'Kape Kanto', [['latte', 1]], 'in_transit', { delivery: f.delivery('live', { pickup_location_id: 'main', dropoff_location_id: 'maritime', progress: 0.45 }) })]), locations: vi.fn(async () => f.locations), telemetry: vi.fn(async () => null), drones: vi.fn(async () => f.drones) }) } })

describe('Test Case ID: CASE-069', () => {
  test(
    'Test Case Description: Customer opens Track while the Kape Kanto order is in flight to the Maritime Building | ' +
      'Expected Result: Track shows the flight in progress, from Main Building to Maritime Building',
    async () => {
      renderPage(<Track />, '/user/track')

      expect(await screen.findByText('Main Building')).toBeInTheDocument()
      expect(screen.getByText('Maritime Building')).toBeInTheDocument()
      expect(screen.getAllByText(/In flight/).length).toBeGreaterThan(0)
      expect(screen.queryByText('No drone in the air for you')).not.toBeInTheDocument()
    },
  )
})
