import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminWeather from '@/pages/admin/weather'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ weather: vi.fn(async () => f.weather), setWeatherOverride: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-140', () => {
  test(
    'Test Case Description: Admin starts the GROUNDED weather override but clicks Cancel on the "Ground every drone?" warning | ' +
      'Expected Result: The warning closes and no weather override is applied',
    async () => {
      renderPage(<AdminWeather />, '/admin/weather')
      const apply = await screen.findAllByRole('button', { name: 'Apply' })
      fireEvent.click(apply[apply.length - 1])
      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Ground every drone?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }))

      await vi.waitFor(() => expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument())
      expect(api.setWeatherOverride).not.toHaveBeenCalled()
    },
  )
})
