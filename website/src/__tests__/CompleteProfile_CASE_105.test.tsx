import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import CompleteProfile from '@/pages/auth/complete-profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ full_name: 'Maria Santos', phone_number: null })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi() }))

describe('Test Case ID: CASE-105', () => {
  test(
    'Test Case Description: Google-signed-in customer without a mobile number enters 12345 on the website Complete your profile page | ' +
      "Expected Result: The number is not saved and 'Enter a Philippine mobile number: 10 digits starting with 9, like 917 123 4567.' is shown",
    async () => {
      renderPage(<CompleteProfile />, '/complete-profile')

      fireEvent.change(screen.getByLabelText('Mobile number'), { target: { value: '12345' } })
      fireEvent.click(screen.getByRole('button', { name: 'Save and continue' }))

      expect(await screen.findByText('Enter a Philippine mobile number: 10 digits starting with 9, like 917 123 4567.')).toBeInTheDocument()
      expect(api.updateProfile).not.toHaveBeenCalled()
    },
  )
})
