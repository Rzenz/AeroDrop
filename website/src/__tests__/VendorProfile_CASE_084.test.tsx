import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Profile from '@/pages/shared/profile'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto', business_category: 'Cafe', full_name: 'Jose Ramirez', email: 'kapekanto@uclm.edu.ph', campus_location_id: 'main' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations) }) } })

describe('Test Case ID: CASE-084', () => {
  test(
    'Test Case Description: Vendor clears the Store name on the website My Profile page and saves | ' +
      "Expected Result: The profile is not saved and 'Enter your store name.' is shown",
    async () => {
      renderPage(<Profile />, '/vendor/profile')
      fireEvent.change(await screen.findByLabelText('Store name'), { target: { value: '' } })
      fireEvent.click(screen.getByRole('button', { name: 'Save changes' }))

      expect(await screen.findByText('Enter your store name.')).toBeInTheDocument()
      expect(api.updateProfile).not.toHaveBeenCalled()
    },
  )
})
