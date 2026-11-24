import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignUp from '@/pages/auth/sign-up'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ checkEmail: vi.fn(async () => ({ ok: true })) }) }))

describe('Test Case ID: CASE-051', () => {
  test(
    'Test Case Description: User enters a Confirm password that differs from the Password on the website Sign Up page | ' +
      "Expected Result: Account is not created and 'Passwords do not match.' is shown",
    () => {
      renderPage(<SignUp />, '/sign-up')
      fireEvent.change(screen.getByLabelText('Full name'), { target: { value: 'Juan Dela Cruz' } })
      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '9171234567' } })
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'juan.delacruz@gmail.com' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.change(screen.getByLabelText('Confirm password'), { target: { value: 'Blue#Sky2025' } })
      fireEvent.click(screen.getByRole('checkbox'))
      fireEvent.click(screen.getByRole('button', { name: 'Create account' }))

      expect(screen.getByText('Passwords do not match.')).toBeInTheDocument()
      expect(api.signUp).not.toHaveBeenCalled()
    },
  )
})
