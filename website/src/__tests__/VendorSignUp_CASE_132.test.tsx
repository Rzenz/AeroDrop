import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignUp from '@/pages/auth/sign-up'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/vendor', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ checkEmail: vi.fn(async () => ({ ok: true })), locations: vi.fn(async () => f.locations), signUp: vi.fn(async () => ({ verify: true })) }) } })

describe('Test Case ID: CASE-132', () => {
  test(
    'Test Case Description: Vendor applicant completes the account step, enters the store name Pan de Mandaue and the stall location UCLM Annex 2, accepts the terms and submits | ' +
      "Expected Result: The application is submitted and the 'Verify your email' code step is shown",
    async () => {
      renderPage(<SignUp />, '/sign-up')
      fireEvent.click(screen.getByRole('tab', { name: 'Vendor' }))
      fireEvent.change(screen.getByLabelText('Full name'), { target: { value: 'Elena Bautista' } })
      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '9171234567' } })
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'pandemandaue@uclm.edu.ph' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.change(screen.getByLabelText('Confirm password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.click(screen.getByRole('button', { name: 'Continue to store details' }))
      fireEvent.change(await screen.findByLabelText('Store name'), { target: { value: 'Pan de Mandaue' } })
      await screen.findByRole('option', { name: 'UCLM Annex 2' })
      fireEvent.change(screen.getByLabelText('Stall location'), { target: { value: 'annex2' } })
      fireEvent.click(screen.getByRole('checkbox'))
      fireEvent.click(screen.getByRole('button', { name: 'Submit application' }))

      expect(await screen.findByText('Verify your email')).toBeInTheDocument()
      expect(api.signUp).toHaveBeenCalledWith(expect.objectContaining({ role: 'vendor', businessName: 'Pan de Mandaue', campusLocationId: 'annex2' }))
    },
  )
})
