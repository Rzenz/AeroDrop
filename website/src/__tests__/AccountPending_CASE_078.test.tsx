import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AccountPending from '@/pages/auth/account-pending'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'pan', role: 'user', vendor_status: 'pending', full_name: 'Elena Bautista', email: 'pandemandaue@uclm.edu.ph', business_name: 'Pan de Mandaue' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({  }) } })

describe('Test Case ID: CASE-078', () => {
  test(
    'Test Case Description: Vendor applicant Pan de Mandaue signs in on the website before an admin approves the store | ' +
      "Expected Result: The 'Application under review' page is shown for Pan de Mandaue",
    () => {
      renderPage(<AccountPending />, '/account-pending')

      expect(screen.getByText('Application under review')).toBeInTheDocument()
      expect(screen.getByText('Pan de Mandaue')).toBeInTheDocument()
      expect(screen.getByText(/Thanks, Elena/)).toBeInTheDocument()
    },
  )
})
