import { fireEvent, screen, within } from '@testing-library/react'
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

describe('Test Case ID: CASE-137', () => {
  test(
    'Test Case Description: Admin rejects the pending vendor application of Pan de Mandaue | ' +
      "Expected Result: A 'Reject Pan de Mandaue?' confirmation appears and confirming rejects the application",
    async () => {
      renderPage(<AdminUsers />, '/admin/users')
      expect(await screen.findByText('Vendor applications')).toBeInTheDocument()
      fireEvent.click(screen.getByRole('button', { name: 'Reject' }))
      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Reject Pan de Mandaue?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Reject application' }))

      await vi.waitFor(() => expect(api.setVendorStatus).toHaveBeenCalledWith('pan', 'rejected'))
      expect(await screen.findByText('Application for "Pan de Mandaue" rejected.')).toBeInTheDocument()
    },
  )
})
