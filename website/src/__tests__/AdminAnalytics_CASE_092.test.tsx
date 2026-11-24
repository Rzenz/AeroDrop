import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Analytics from '@/pages/admin/analytics'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const f = await import('./fixtures')
  const now = new Date().toISOString()
  const done = (id: string, vendor: string, name: string, line: [string, number][]) => f.order(id, vendor, name, line, 'delivered', { created_at: now, delivery: f.delivery(id, { status: 'delivered', progress: 1, delivery_started_at: now, delivery_completed_at: new Date(Date.parse(now) + 250_000).toISOString() }) })
  const orders = [
    done('a', 'kape', 'Kape Kanto', [['latte', 1]]),
    done('b', 'kape', 'Kape Kanto', [['americano', 1]]),
    done('c', 'canteen', 'UCLM Canteen', [['adobo', 1]]),
    f.order('d', 'tea', 'Tea Haus', [['classic', 1]], 'cancelled', { created_at: now }),
  ]
  return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ orders: vi.fn(async () => orders) }) }
})

describe('Test Case ID: CASE-092', () => {
  test(
    'Test Case Description: Admin opens Analytics with 3 delivered orders (P120 + P85 + P95 plus P23.19 fee each) and 1 cancelled order this week | ' +
      'Expected Result: Totals show Success Rate 75%, Total Revenue P369.57 and an average flight time of 4m 10s',
    async () => {
      renderPage(<Analytics />, '/admin/analytics')

      expect((await screen.findAllByText('75%')).length).toBeGreaterThan(0)
      expect(screen.getAllByText('₱369.57').length).toBeGreaterThan(0)
      expect(screen.getByText('4m 10s')).toBeInTheDocument()
    },
  )
})
