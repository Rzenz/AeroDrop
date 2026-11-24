import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { VerifyEmailBanner } from '@/components/verify-email'
import { api } from '@/data/api'
import { profile, renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ refresh: vi.fn() }) }))
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ sendEmailVerificationCode: vi.fn(async () => undefined), verifyEmailCode: vi.fn(async () => undefined) }) }))

describe('Test Case ID: CASE-123', () => {
  test(
    'Test Case Description: Customer with an unverified email enters the full 6-digit code (482913) from the verification email | ' +
      "Expected Result: The email is verified and 'Email verified. You can now place orders.' is shown",
    async () => {
      const paolo = profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph', email_verified_at: null })
      renderPage(<VerifyEmailBanner me={paolo} />)
      fireEvent.click(screen.getByRole('button', { name: 'Verify email' }))
      const dialog = await screen.findByRole('dialog')
      await vi.waitFor(() => expect(api.sendEmailVerificationCode).toHaveBeenCalled())
      fireEvent.change(within(dialog).getAllByRole('textbox')[0], { target: { value: '482913' } })
      fireEvent.click(within(dialog).getByRole('button', { name: 'Verify email' }))

      await vi.waitFor(() => expect(api.verifyEmailCode).toHaveBeenCalledWith('482913'))
      expect(await screen.findByText('Email verified. You can now place orders.')).toBeInTheDocument()
    },
  )
})
