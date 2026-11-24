import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignUp from '@/pages/auth/sign-up'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/vendor', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ checkEmail: vi.fn(async () => ({ ok: true })), locations: vi.fn(async () => f.locations) }) } })

describe('Test Case ID: CASE-077', () => {
  test(
    'Test Case Description: Vendor applicant completes the account step but leaves the store name and stall location empty | ' +
      "Expected Result: Application is not submitted; 'Enter your store name.' and 'Choose where your stall is.' are shown",
    async () => {
      renderPage(<SignUp />, '/sign-up')
      fireEvent.click(screen.getByRole('tab', { name: 'Vendor' }))
      fireEvent.change(screen.getByLabelText('Full name'), { target: { value: 'Elena Bautista' } })
      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '9171234567' } })
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'elena.bautista@gmail.com' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.change(screen.getByLabelText('Confirm password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.click(screen.getByRole('button', { name: 'Continue to store details' }))

      fireEvent.click(await screen.findByRole('checkbox'))
      fireEvent.click(screen.getByRole('button', { name: 'Submit application' }))

      expect(await screen.findByText('Enter your store name.')).toBeInTheDocument()
      expect(screen.getByText('Choose where your stall is.')).toBeInTheDocument()
      expect(api.signUp).not.toHaveBeenCalled()
    },
  )
})
