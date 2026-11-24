import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { VerifyEmailBanner } from '@/components/verify-email'
import { api } from '@/data/api'
import { needsEmailVerification } from '@/lib/email-verification'
import { profile, renderPage } from './helpers'

vi.mock('@/auth/auth', () => ({ useAuth: () => ({ refresh: vi.fn() }) }))
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ sendEmailVerificationCode: vi.fn(async () => undefined), verifyEmailCode: vi.fn(async () => undefined) }) }))

describe('Test Case ID: CASE-055', () => {
  test(
    'Test Case Description: Customer with an unverified email enters only 5 of the 6 code digits | ' +
      "Expected Result: Banner asks them to verify, a code is emailed, and 'Enter all 6 digits.' is shown",
    async () => {
      const paolo = profile({ id: 'paolo', full_name: 'Paolo Reyes', email: 'paolo.reyes@uclm.edu.ph', email_verified_at: null })
      expect(needsEmailVerification(paolo)).toBe(true)

      renderPage(<VerifyEmailBanner me={paolo} />)
      expect(screen.getByText('Verify your email to start ordering.')).toBeInTheDocument()
      fireEvent.click(screen.getByRole('button', { name: 'Verify email' }))

      const dialog = await screen.findByRole('dialog')
      await vi.waitFor(() => expect(api.sendEmailVerificationCode).toHaveBeenCalled())
      fireEvent.change(within(dialog).getAllByRole('textbox')[0], { target: { value: '12345' } })
      fireEvent.click(within(dialog).getByRole('button', { name: 'Verify email' }))

      expect(await within(dialog).findByText('Enter all 6 digits.')).toBeInTheDocument()
      expect(api.verifyEmailCode).not.toHaveBeenCalled()
    },
  )
})
