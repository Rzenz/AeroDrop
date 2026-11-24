import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignIn from '@/pages/auth/sign-in'
import { authMessage } from '@/data/auth-errors'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
// Supabase answers a wrong password with invalid_credentials; live-api turns it into authMessage().
vi.mock('@/data/api', async () => ({
  ...(await import('@/data/auth-errors')),
  api: (await import('./helpers')).fakeApi({
    signIn: vi.fn(async () => {
      throw new Error(authMessage({ code: 'invalid_credentials', message: 'Invalid login credentials' }))
    }),
  }),
}))

describe('Test Case ID: CASE-050', () => {
  test(
    'Test Case Description: User enters a registered email with a wrong password on the website | ' +
      "Expected Result: Sign in fails with 'Incorrect email or password.' error message",
    async () => {
      renderPage(<SignIn />, '/sign-in')
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'maria.santos@uclm.edu.ph' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'wrongpass1' } })
      fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

      expect(await screen.findByText('Incorrect email or password.')).toBeInTheDocument()
    },
  )
})
