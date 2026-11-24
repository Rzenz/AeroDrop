import { fireEvent, screen, within } from '@testing-library/react'
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
  return { ...(await import('@/data/auth-errors')), api: fakeApi({ profile: vi.fn(async () => profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph' })), setAccountStatus: vi.fn(async () => undefined) }) }
})

describe('Test Case ID: CASE-088', () => {
  test(
    'Test Case Description: Admin suspends the customer account of Paolo Reyes | ' +
      'Expected Result: A "Suspend Paolo Reyes?" confirmation appears and confirming sets the account to suspended',
    async () => {
      renderRoute(<AdminUserDetail />, '/admin/users/:id', '/admin/users/paolo')

      fireEvent.click(await screen.findByRole('button', { name: 'Suspend account' }))
      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Suspend Paolo Reyes?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Suspend account' }))

      await vi.waitFor(() => expect(api.setAccountStatus).toHaveBeenCalledWith('paolo', 'suspended'))
    },
  )
})
