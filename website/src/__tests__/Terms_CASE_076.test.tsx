import { screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Legal from '@/pages/legal'
import { renderPage } from './helpers'

// The page header's store link reads the site config, which needs the live Supabase keys.
vi.mock('@/lib/config', () => ({ PLAY_STORE_URL: '' }))

describe('Test Case ID: CASE-076', () => {
  test(
    'Test Case Description: Visitor opens the Terms & Conditions page on the website | ' +
      'Expected Result: The page shows its sections, starting with Payload Responsibilities',
    () => {
      renderPage(<Legal page="terms" />, '/terms')

      expect(screen.getByRole('heading', { name: 'Terms & Conditions' })).toBeInTheDocument()
      expect(screen.getByText('1. Payload Responsibilities')).toBeInTheDocument()
      expect(screen.getByText('2. Automated Flight Paths')).toBeInTheDocument()
      expect(screen.getByText(/0.5 kg per-trip/)).toBeInTheDocument()
    },
  )
})
