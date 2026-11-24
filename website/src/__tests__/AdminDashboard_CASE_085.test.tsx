import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminDashboard from '@/pages/admin/dashboard'
import { renderPage } from './helpers'

vi.mock('@/components/campus-map', () => ({ CampusMap: () => null }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ orders: vi.fn(async () => [f.order('live', 'kape', 'Kape Kanto', [['latte', 1]], 'in_transit', { delivery: f.delivery('live') }), f.order('h1', 'canteen', 'UCLM Canteen', [['adobo', 1]], 'delivered', { delivery: f.delivery('h1', { status: 'delivered', progress: 1 }) }), f.order('h3', 'kape', 'Kape Kanto', [['croissant', 2]], 'cancelled')]), drones: vi.fn(async () => [...f.drones, { ...f.drones[0], id: 'drn3', drone_code: 'DRN-003', status: 'maintenance' }]), weather: vi.fn(async () => f.weather), vendors: vi.fn(async () => f.vendors) }) } })

describe('Test Case ID: CASE-085', () => {
  test(
    'Test Case Description: Admin opens the Command Deck dashboard with 1 order in flight, 1 delivered, 1 cancelled and 3 drones (1 in maintenance) | ' +
      'Expected Result: Dashboard shows Active Flights 1, Fleet Online 2/3 and Success Rate 50%',
    async () => {
      renderPage(<AdminDashboard />, '/admin')

      expect(await screen.findByText('2/3')).toBeInTheDocument()
      expect(screen.getByText('Active Flights').closest('div')!.parentElement).toHaveTextContent('1')
      expect(await screen.findByText('50%')).toBeInTheDocument()
    },
  )
})
