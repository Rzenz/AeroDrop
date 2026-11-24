import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Help from '@/pages/shared/help'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ reports: vi.fn(async () => []), submitReport: vi.fn(async () => 'r-new') }) }))

describe('Test Case ID: CASE-131', () => {
  test(
    'Test Case Description: Customer sends a New Report with the subject "Drone landed at the wrong building" and a short description | ' +
      "Expected Result: The report is sent and 'Support ticket submitted successfully! Our campus fleet team will review it.' is shown",
    async () => {
      renderPage(<Help />, '/user/help')
      fireEvent.click(await screen.findByRole('button', { name: 'New Report' }))
      fireEvent.change(screen.getByLabelText('Subject'), { target: { value: 'Drone landed at the wrong building' } })
      fireEvent.change(screen.getByLabelText('What happened?'), { target: { value: 'My order was dropped at the Annex instead of the Maritime Building.' } })
      fireEvent.click(screen.getByRole('button', { name: 'Send report' }))

      await vi.waitFor(() => expect(api.submitReport).toHaveBeenCalledWith(expect.objectContaining({ subject: 'Drone landed at the wrong building' })))
      expect(await screen.findByText('Support ticket submitted successfully! Our campus fleet team will review it.')).toBeInTheDocument()
    },
  )
})
