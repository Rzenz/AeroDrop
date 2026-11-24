import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminSupport from '@/pages/admin/support'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ reports: vi.fn(async () => [f.report('rep1', 'Drone landed at the wrong building', 'open')]), updateReport: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-093', () => {
  test(
    'Test Case Description: Admin resolves the open support report "Drone landed at the wrong building" | ' +
      "Expected Result: The report is marked resolved and 'Report resolved. The customer was notified.' is shown",
    async () => {
      renderPage(<AdminSupport />, '/admin/support')
      expect((await screen.findAllByText('Drone landed at the wrong building')).length).toBeGreaterThan(0)

      fireEvent.click(screen.getByRole('button', { name: 'Resolve' }))

      await vi.waitFor(() => expect(api.updateReport).toHaveBeenCalledWith('rep1', expect.objectContaining({ status: 'resolved' })))
      expect(await screen.findByText('Report resolved. The customer was notified.')).toBeInTheDocument()
    },
  )
})
