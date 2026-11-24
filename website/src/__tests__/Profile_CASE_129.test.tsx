import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Profile from '@/pages/shared/profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => (await import('./fixtures')).locations), updateProfile: vi.fn(async () => undefined) }) }))

describe('Test Case ID: CASE-129', () => {
  test(
    'Test Case Description: Customer changes their full name to "Maria L. Santos" on the website Profile page and saves | ' +
      "Expected Result: The profile is saved and 'Profile saved.' is shown",
    async () => {
      renderPage(<Profile />, '/user/profile')
      fireEvent.change(await screen.findByLabelText('Full name'), { target: { value: 'Maria L. Santos' } })
      fireEvent.click(screen.getByRole('button', { name: 'Save changes' }))

      await vi.waitFor(() => expect(api.updateProfile).toHaveBeenCalledWith('maria', expect.objectContaining({ full_name: 'Maria L. Santos' })))
      expect(await screen.findByText('Profile saved.')).toBeInTheDocument()
    },
  )
})
