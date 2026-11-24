import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminUsers from '@/pages/admin/users'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const { fakeApi, profile } = await import('./helpers')
  const users = [
    profile({ id: 'maria' }),
    profile({ id: 'pan', role: 'vendor', vendor_status: 'pending', full_name: 'Elena Bautista', email: 'pandemandaue@uclm.edu.ph', business_name: 'Pan de Mandaue', business_category: 'Bakery', business_description: 'Pandesal, ensaymada and ube cheese rolls baked on campus.' }),
  ]
  return { ...(await import('@/data/auth-errors')), api: fakeApi({ users: vi.fn(async () => users), setVendorStatus: vi.fn(async () => undefined) }) }
})

describe('Test Case ID: CASE-087', () => {
  test(
    'Test Case Description: Admin approves the pending vendor application of Pan de Mandaue | ' +
      "Expected Result: The store is set to active and 'Pan de Mandaue approved.' is shown",
    async () => {
      renderPage(<AdminUsers />, '/admin/users')
      expect(await screen.findByText('Vendor applications')).toBeInTheDocument()

      fireEvent.click(screen.getByRole('button', { name: 'Approve' }))

      await vi.waitFor(() => expect(api.setVendorStatus).toHaveBeenCalledWith('pan', 'active'))
      expect(await screen.findByText('Pan de Mandaue approved.')).toBeInTheDocument()
    },
  )
})
