import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Profile from '@/pages/shared/profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => (await import('./fixtures')).locations) }) }))

describe('Test Case ID: CASE-071', () => {
  test(
    'Test Case Description: Customer clears their full name on the Profile page and saves | ' +
      "Expected Result: Profile is not saved and 'Enter your full name.' is shown",
    async () => {
      renderPage(<Profile />, '/user/profile')
      fireEvent.change(await screen.findByLabelText('Full name'), { target: { value: '' } })
      fireEvent.click(screen.getByRole('button', { name: 'Save changes' }))

      expect(await screen.findByText('Enter your full name.')).toBeInTheDocument()
      expect(api.updateProfile).not.toHaveBeenCalled()
    },
  )
})
