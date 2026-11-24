import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignIn from '@/pages/auth/sign-in'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => ({
  ...(await import('@/data/auth-errors')),
  api: (await import('./helpers')).fakeApi({ signIn: vi.fn(async () => (await import('./helpers')).profile({})) }),
}))

describe('Test Case ID: CASE-120', () => {
  test(
    'Test Case Description: User enters a registered email and the correct password on the website Sign In page | ' +
      'Expected Result: Sign in succeeds and the customer Home page opens',
    async () => {
      renderRoute(<SignIn />, '/sign-in', '/sign-in')
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'maria.santos@uclm.edu.ph' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'demo1234' } })
      fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

      expect(await screen.findByText('Navigated away')).toBeInTheDocument()
      expect(api.signIn).toHaveBeenCalledWith('maria.santos@uclm.edu.ph', 'demo1234')
    },
  )
})
