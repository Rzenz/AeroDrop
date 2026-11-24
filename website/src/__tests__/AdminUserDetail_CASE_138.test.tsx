import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminUserDetail from '@/pages/admin/user-detail'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'admin', role: 'admin', full_name: 'AeroDrop Admin', email: 'admin.portal@uclm.edu', phone_number: null })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => {
  const { fakeApi, profile } = await import('./helpers')
  return { ...(await import('@/data/auth-errors')), api: fakeApi({ profile: vi.fn(async () => profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph', account_status: 'suspended' })), setAccountStatus: vi.fn(async () => undefined) }) }
})

describe('Test Case ID: CASE-138', () => {
  test(
    'Test Case Description: Admin reactivates the suspended customer account of Paolo Reyes | ' +
      "Expected Result: The account is set back to active and 'Account reactivated.' is shown",
    async () => {
      renderRoute(<AdminUserDetail />, '/admin/users/:id', '/admin/users/paolo')
      expect(screen.queryByRole('button', { name: 'Suspend account' })).not.toBeInTheDocument()
      fireEvent.click(await screen.findByRole('button', { name: 'Reactivate account' }))

      await vi.waitFor(() => expect(api.setAccountStatus).toHaveBeenCalledWith('paolo', 'active'))
      expect(await screen.findByText('Account reactivated.')).toBeInTheDocument()
    },
  )
})
