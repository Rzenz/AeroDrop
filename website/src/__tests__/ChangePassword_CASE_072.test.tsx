import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Profile from '@/pages/shared/profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations) }) } })

describe('Test Case ID: CASE-072', () => {
  test(
    'Test Case Description: Customer changes their password to "abc" (3 characters) on the website Profile page | ' +
      "Expected Result: The password is not changed and 'Password must be at least 6 characters' is shown",
    async () => {
      renderPage(<Profile />, '/user/profile')
      fireEvent.change(await screen.findByLabelText('Current password'), { target: { value: 'demo1234' } })
      fireEvent.change(screen.getByLabelText('New password'), { target: { value: 'abc' } })
      fireEvent.change(screen.getByLabelText('Confirm new password'), { target: { value: 'abc' } })
      fireEvent.click(screen.getByRole('button', { name: 'Update password' }))

      expect(await screen.findByText('Password must be at least 6 characters')).toBeInTheDocument()
      expect(api.changePassword).not.toHaveBeenCalled()
    },
  )
})
