import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import SupportThread from '@/pages/shared/support-thread'
import { api } from '@/data/api'
import { renderRoute } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ report: vi.fn(async () => f.report('rep1', 'Drone landed at the wrong building', 'open')), supportMessages: vi.fn(async () => []), sendSupportMessage: vi.fn(async () => undefined), subscribeSupportMessages: vi.fn(() => () => {}), markSupportRead: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-074', () => {
  test(
    'Test Case Description: Customer replies on their open support report "Drone landed at the wrong building" | ' +
      'Expected Result: The reply is sent to the support conversation and the message box is cleared',
    async () => {
      renderRoute(<SupportThread />, '/user/help/:reportId', '/user/help/rep1')
      expect(await screen.findByText('Drone landed at the wrong building')).toBeInTheDocument()

      const box = screen.getByPlaceholderText('Write a message')
      fireEvent.change(box, { target: { value: 'I have a photo of where it landed, sending it shortly.' } })
      fireEvent.click(screen.getByRole('button', { name: 'Send' }))

      await vi.waitFor(() => expect(api.sendSupportMessage).toHaveBeenCalledWith('rep1', 'I have a photo of where it landed, sending it shortly.', []))
      await vi.waitFor(() => expect(box).toHaveValue(''))
    },
  )
})
