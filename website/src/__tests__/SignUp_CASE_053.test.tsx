import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SignUp from '@/pages/auth/sign-up'
import { passwordStrength } from '@/lib/password-strength'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ user: null, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }))
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi() }))

describe('Test Case ID: CASE-053', () => {
  test(
    'Test Case Description: User types a common password (password123) on the website Sign Up page | ' +
      'Expected Result: Strength meter rates it Weak and warns it is one of the most common passwords',
    () => {
      const result = passwordStrength('password123', ['Juan Dela Cruz'])
      expect(result.label).toBe('Weak')
      expect(result.level).toBe(1)

      renderPage(<SignUp />, '/sign-up')
      fireEvent.change(screen.getByLabelText('Full name'), { target: { value: 'Juan Dela Cruz' } })
      fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password123' } })

      expect(screen.getByText('Weak')).toBeInTheDocument()
      expect(screen.getByText('This is one of the most common passwords. Pick something only you would know.')).toBeInTheDocument()
    },
  )
})
