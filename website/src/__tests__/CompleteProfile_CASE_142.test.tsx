import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import CompleteProfile from '@/pages/auth/complete-profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ full_name: 'Maria Santos', phone_number: null })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ updateProfile: vi.fn(async () => undefined) }) }))

describe('Test Case ID: CASE-142', () => {
  test(
    'Test Case Description: Google-signed-in customer without a mobile number enters 917 123 4567 on the website Complete your profile page | ' +
      "Expected Result: The number is saved and 'Profile completed successfully! Welcome to AeroDrop.' is shown",
    async () => {
      renderPage(<CompleteProfile />, '/complete-profile')
      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '9171234567' } })
      fireEvent.click(screen.getByRole('button', { name: 'Save and continue' }))

      await vi.waitFor(() => expect(api.updateProfile).toHaveBeenCalledWith('u1', expect.objectContaining({ phone_number: '+639171234567' })))
      expect(await screen.findByText('Profile completed successfully! Welcome to AeroDrop.')).toBeInTheDocument()
    },
  )
})
