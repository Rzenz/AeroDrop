import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignIn from '@/pages/auth/sign-in'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi() }))

describe('Test Case ID: CASE-049', () => {
  test(
    'Test Case Description: User enters invalid email format on the website Sign In page | ' +
      "Expected Result: Sign in fails with 'Enter the email you registered with.' error message",
    () => {
      renderPage(<SignIn />, '/sign-in')
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'invalidemail' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: '123456' } })
      fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

      expect(screen.getByText('Enter the email you registered with.')).toBeInTheDocument()
      expect(api.signIn).not.toHaveBeenCalled()
    },
  )
})
