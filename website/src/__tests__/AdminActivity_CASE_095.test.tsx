import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import ActivityLogs from '@/pages/admin/activity'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const { fakeApi, profile } = await import('./helpers')
  const users = [
    profile({ id: 'maria', full_name: 'Maria Santos', created_at: '2026-10-08T08:00:00Z' }),
    profile({ id: 'pan', role: 'vendor', vendor_status: 'pending', full_name: 'Elena Bautista', created_at: '2026-11-16T08:00:00Z' }),
    profile({ id: 'joy', full_name: 'Joy Dizon', created_at: '2026-10-01T08:00:00Z' }),
  ]
  return { ...(await import('@/data/auth-errors')), api: fakeApi({ users: vi.fn(async () => users), statusLogs: vi.fn(async () => []), safetyChecks: vi.fn(async () => []) }) }
})

describe('Test Case ID: CASE-095', () => {
  test(
    'Test Case Description: Admin opens Activity Logs | ' +
      'Expected Result: User activity lists the most recent registrations, newest first (Elena Bautista first)',
    async () => {
      renderPage(<ActivityLogs />, '/admin/reports')

      const names = (await screen.findAllByText(/Elena Bautista|Maria Santos|Joy Dizon/)).map((e) => e.textContent)
      expect(names).toEqual(['Elena Bautista', 'Maria Santos', 'Joy Dizon'])
    },
  )
})
