import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Profile from '@/pages/shared/profile'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const me = (await import('./helpers')).profile({ id: 'maria', campus_location_id: 'maritime' })
  return { useMe: () => me, useAuth: () => ({ user: me, ready: true, refresh: vi.fn(), signOut: vi.fn() }), homeFor: () => '/user', markUnlocked: vi.fn() }
})
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations) }) } })

describe('Test Case ID: CASE-075', () => {
  test(
    'Test Case Description: Customer turns on Dark theme on the website Profile page | ' +
      'Expected Result: The Dark theme switch turns on and the site switches to the dark theme',
    async () => {
      document.documentElement.dataset.theme = 'light'
      renderPage(<Profile />, '/user/profile')
      const toggle = await screen.findByRole('switch', { name: 'Dark theme' })
      expect(toggle).not.toBeChecked()

      fireEvent.click(toggle)

      expect(toggle).toBeChecked()
      expect(document.documentElement.dataset.theme).toBe('dark')
    },
  )
})
