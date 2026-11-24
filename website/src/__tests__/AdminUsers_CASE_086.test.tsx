import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminUsers from '@/pages/admin/users'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => {
  const { fakeApi, profile } = await import('./helpers')
  const users = [
    profile({ id: 'maria', full_name: 'Maria Santos', email: 'maria.santos@uclm.edu.ph' }),
    profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph' }),
    profile({ id: 'angel', full_name: 'Angel Cruz', email: 'angel.cruz@uclm.edu.ph' }),
    profile({ id: 'joy', full_name: 'Joy Dizon', email: 'joy.dizon@uclm.edu.ph' }),
  ]
  return { ...(await import('@/data/auth-errors')), api: fakeApi({ users: vi.fn(async () => users) }) }
})

describe('Test Case ID: CASE-086', () => {
  test(
    'Test Case Description: Admin searches the Users & Vendors list for "maria" | ' +
      'Expected Result: Only the matching account (Maria Santos) is listed',
    async () => {
      renderPage(<AdminUsers />, '/admin/users')
      expect(await screen.findByText('Paolo Reyes')).toBeInTheDocument()

      fireEvent.change(screen.getByLabelText('Search accounts'), { target: { value: 'maria' } })

      expect(screen.getByText('Maria Santos')).toBeInTheDocument()
      expect(screen.queryByText('Paolo Reyes')).not.toBeInTheDocument()
      expect(screen.queryByText('Angel Cruz')).not.toBeInTheDocument()
      expect(screen.queryByText('Joy Dizon')).not.toBeInTheDocument()
    },
  )
})
