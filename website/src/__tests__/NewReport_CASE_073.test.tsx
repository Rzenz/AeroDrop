import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Help from '@/pages/shared/help'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ reports: vi.fn(async () => []) }) } })

describe('Test Case ID: CASE-073', () => {
  test(
    'Test Case Description: Customer opens New Report on Help & Support and sends it with the subject "Hi" and no details | ' +
      "Expected Result: The report is not sent and 'Give the report a short subject.' is shown",
    async () => {
      renderPage(<Help />, '/user/help')
      fireEvent.click(await screen.findByRole('button', { name: 'New Report' }))
      fireEvent.change(screen.getByLabelText('Subject'), { target: { value: 'Hi' } })
      fireEvent.click(screen.getByRole('button', { name: 'Send report' }))

      expect(await screen.findByText('Give the report a short subject.')).toBeInTheDocument()
      expect(api.submitReport).not.toHaveBeenCalled()
    },
  )
})
