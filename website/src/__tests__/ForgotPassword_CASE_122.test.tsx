import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import ForgotPassword from '@/pages/auth/forgot-password'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ sendPasswordReset: vi.fn(async () => undefined) }) }))

describe('Test Case ID: CASE-122', () => {
  test(
    'Test Case Description: User requests a reset code with the registered email maria.santos@uclm.edu.ph on the website | ' +
      "Expected Result: The code is sent and the 'Choose a new password' step is shown",
    async () => {
      renderPage(<ForgotPassword />, '/forgot-password')
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'maria.santos@uclm.edu.ph' } })
      fireEvent.click(screen.getByRole('button', { name: 'Send code' }))

      expect(await screen.findByText('Choose a new password')).toBeInTheDocument()
      expect(api.sendPasswordReset).toHaveBeenCalledWith('maria.santos@uclm.edu.ph')
      expect(screen.getByLabelText('New password')).toBeInTheDocument()
    },
  )
})
