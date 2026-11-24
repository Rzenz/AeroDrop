import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignUp from '@/pages/auth/sign-up'
import { api } from '@/data/api'
import { PH_PHONE_ERROR } from '@/lib/phone'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ checkEmail: vi.fn(async () => ({ ok: true })) }) }))

describe('Test Case ID: CASE-052', () => {
  test(
    'Test Case Description: User enters an invalid mobile number (12345) on the website Sign Up page | ' +
      'Expected Result: Account is not created and the Philippine mobile number error is shown',
    () => {
      renderPage(<SignUp />, '/sign-up')
      fireEvent.change(screen.getByLabelText('Full name'), { target: { value: 'Juan Dela Cruz' } })
      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '12345' } })
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'juan.delacruz@gmail.com' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.change(screen.getByLabelText('Confirm password'), { target: { value: 'Blue#Sky2026' } })
      fireEvent.click(screen.getByRole('checkbox'))
      fireEvent.click(screen.getByRole('button', { name: 'Create account' }))

      expect(screen.getByText(PH_PHONE_ERROR)).toBeInTheDocument()
      expect(PH_PHONE_ERROR).toBe('Enter a Philippine mobile number: 10 digits starting with 9, like 917 123 4567.')
      expect(api.signUp).not.toHaveBeenCalled()
    },
  )
})
