import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import ForgotPassword from '@/pages/auth/forgot-password'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi() }))

describe('Test Case ID: CASE-054', () => {
  test(
    'Test Case Description: User requests a reset code with an invalid email (juan.delacruz@gmail) on the website | ' +
      "Expected Result: No code is sent and 'Enter the email you registered with.' is shown",
    () => {
      renderPage(<ForgotPassword />, '/forgot-password')
      fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'juan.delacruz@gmail' } })
      fireEvent.click(screen.getByRole('button', { name: 'Send code' }))

      expect(screen.getByText('Enter the email you registered with.')).toBeInTheDocument()
      expect(api.sendPasswordReset).not.toHaveBeenCalled()
    },
  )
})
