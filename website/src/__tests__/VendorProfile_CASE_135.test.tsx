import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Profile from '@/pages/shared/profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', business_category: 'Cafe', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations), updateProfile: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-135', () => {
  test(
    'Test Case Description: Vendor changes the Store name to "Kape Kanto Express" on the website My Profile page and saves | ' +
      "Expected Result: The store details are saved and 'Profile saved.' is shown",
    async () => {
      renderPage(<Profile />, '/vendor/profile')
      fireEvent.change(await screen.findByLabelText('Store name'), { target: { value: 'Kape Kanto Express' } })
      fireEvent.click(screen.getByRole('button', { name: 'Save changes' }))

      await vi.waitFor(() => expect(api.updateProfile).toHaveBeenCalledWith('kape', expect.objectContaining({ business_name: 'Kape Kanto Express' })))
      expect(await screen.findByText('Profile saved.')).toBeInTheDocument()
    },
  )
})
