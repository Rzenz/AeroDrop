import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { PortalLayout } from '@/layouts/portal-layout'
import { renderRoute } from './helpers'

const signOut = vi.hoisted(() => vi.fn(async () => undefined))
vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({})
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ subscribeChanges: vi.fn(() => () => {}) }) }))
// The portal's background drone simulator is not part of this case.
vi.mock('@/lib/dispatch', () => ({ markOrderReadyAndDispatch: vi.fn() }))
// The sidebar logo reads the app config, which needs the live Supabase keys; the test needs none of it.
vi.mock('@/lib/config', () => ({ supabase: {}, PLAY_STORE_URL: null, isAdminEmail: () => false }))

describe('Test Case ID: CASE-101', () => {
  test(
    'Test Case Description: Customer clicks Sign out in the website sidebar and confirms | ' +
      'Expected Result: The account is signed out and the Sign In page is opened',
    async () => {
      renderRoute(<PortalLayout role="user" />, '/user/*', '/user')

      fireEvent.click(screen.getAllByRole('button', { name: 'Sign out' })[0])
      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Sign out?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Sign out' }))

      await vi.waitFor(() => expect(signOut).toHaveBeenCalledTimes(1))
      expect(await screen.findByText('Navigated away')).toBeInTheDocument()
    },
  )
})
