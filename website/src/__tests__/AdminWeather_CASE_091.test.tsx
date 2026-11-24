import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import AdminWeather from '@/pages/admin/weather'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ weather: vi.fn(async () => f.weather), setWeatherOverride: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-091', () => {
  test(
    'Test Case Description: Admin applies the GROUNDED weather override | ' +
      'Expected Result: A "Ground every drone?" warning appears and confirming applies the grounded override',
    async () => {
      renderPage(<AdminWeather />, '/admin/weather')
      const apply = await screen.findAllByRole('button', { name: 'Apply' })
      fireEvent.click(apply[apply.length - 1])

      const dialog = await screen.findByRole('alertdialog')
      expect(within(dialog).getByText('Ground every drone?')).toBeInTheDocument()
      fireEvent.click(within(dialog).getByRole('button', { name: 'Ground the fleet' }))

      await vi.waitFor(() => expect(api.setWeatherOverride).toHaveBeenCalledWith('grounded'))
    },
  )
})
