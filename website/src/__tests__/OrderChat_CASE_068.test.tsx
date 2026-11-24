import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { OrderChat } from '@/components/order-chat'
import { api } from '@/data/api'
import { delivery, order } from './fixtures'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ messages: vi.fn(async () => []), chatCounterpart: vi.fn(async () => ({ role: 'vendor', name: 'Kape Kanto', avatarUrl: null })), sendMessage: vi.fn(async () => undefined), subscribeMessages: vi.fn(() => () => {}) }) }))

describe('Test Case ID: CASE-068', () => {
  test(
    'Test Case Description: Customer sends a message to Kape Kanto about an order that is in flight | ' +
      'Expected Result: The message is sent to the vendor and the message box is cleared',
    async () => {
      renderPage(<OrderChat order={order('live', 'kape', 'Kape Kanto', [['latte', 1]], 'in_transit', { delivery: delivery('live') })} />)
      const box = await screen.findByPlaceholderText('Message Kape Kanto')
      fireEvent.change(box, { target: { value: 'Please leave it with the guard if I am not there.' } })
      fireEvent.click(screen.getByRole('button', { name: 'Send message' }))

      await vi.waitFor(() => expect(api.sendMessage).toHaveBeenCalledWith('live', 'Please leave it with the guard if I am not there.'))
      await vi.waitFor(() => expect(box).toHaveValue(''))
    },
  )
})
