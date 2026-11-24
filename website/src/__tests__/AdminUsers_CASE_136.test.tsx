import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminUsers from '@/pages/admin/users'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const { fakeApi, profile } = await import('./helpers')
  const users = [
    profile({ id: 'maria', full_name: 'Maria Santos', email: 'maria.santos@uclm.edu.ph' }),
    profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph' }),
  ]
  return { ...(await import('@/data/auth-errors')), api: fakeApi({ users: vi.fn(async () => users) }) }
})

describe('Test Case ID: CASE-136', () => {
  test(
    'Test Case Description: Admin searches the Users & Vendors list for "zzz", which matches no account | ' +
      "Expected Result: No account is listed and 'No accounts here' with 'Try another search.' is shown",
    async () => {
      renderPage(<AdminUsers />, '/admin/users')
      expect(await screen.findByText('Paolo Reyes')).toBeInTheDocument()
      fireEvent.change(screen.getByLabelText('Search accounts'), { target: { value: 'zzz' } })

      expect(screen.getByText('No accounts here')).toBeInTheDocument()
      expect(screen.getByText('Try another search.')).toBeInTheDocument()
      expect(screen.queryByText('Maria Santos')).not.toBeInTheDocument()
    },
  )
})
