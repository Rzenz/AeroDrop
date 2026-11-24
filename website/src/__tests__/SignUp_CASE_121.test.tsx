import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignUp from '@/pages/auth/sign-up'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
// Supabase creates the account and asks for the emailed confirmation code.
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ checkEmail: vi.fn(async () => ({ ok: true })), signUp: vi.fn(async () => ({ verify: true })) }) }))

describe('Test Case ID: CASE-121', () => {
  test(
    'Test Case Description: User fills in every Sign Up field correctly, accepts the terms and clicks Create account | ' +
      "Expected Result: The account is created and the 'Verify your email' code step is shown",
    async () => {
      renderPage(<SignUp />, '/sign-up')
      fireEvent.change(screen.getByLabelText('Full name'), { target: { value: 'Juan Dela Cruz' } })
      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '9171234567' } })
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'juan.delacruz@uclm.edu.ph' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.change(screen.getByLabelText('Confirm password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.click(screen.getByRole('checkbox'))
      fireEvent.click(screen.getByRole('button', { name: 'Create account' }))

      expect(await screen.findByText('Verify your email')).toBeInTheDocument()
      expect(api.signUp).toHaveBeenCalledWith(expect.objectContaining({ fullName: 'Juan Dela Cruz', email: 'juan.delacruz@uclm.edu.ph', phone: '+639171234567', role: 'user' }))
    },
  )
})
