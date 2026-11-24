import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import FlightBoundaries from '@/pages/admin/boundaries'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/components/campus-map', () => ({ CampusMap: () => null }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations), zones: vi.fn(async () => []) }) } })

describe('Test Case ID: CASE-094', () => {
  test(
    'Test Case Description: Admin adds a no-fly zone "Gymnasium Roof" with a 1000 m radius | ' +
      "Expected Result: Zone is not saved and 'Use a radius between 5 and 500 metres.' is shown",
    async () => {
      renderPage(<FlightBoundaries />, '/admin/routes/no-fly-zones')
      fireEvent.click(await screen.findByRole('button', { name: 'Add' }))

      const dialog = await screen.findByRole('dialog')
      fireEvent.change(within(dialog).getByLabelText('Name'), { target: { value: 'Gymnasium Roof' } })
      fireEvent.change(within(dialog).getByLabelText(/Radius/), { target: { value: '1000' } })
      fireEvent.click(within(dialog).getByRole('button', { name: 'Save zone' }))

      expect(await within(dialog).findByText('Use a radius between 5 and 500 metres.')).toBeInTheDocument()
      expect(api.saveZone).not.toHaveBeenCalled()
    },
  )
})
