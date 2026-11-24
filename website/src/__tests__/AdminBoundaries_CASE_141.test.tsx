import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import FlightBoundaries from '@/pages/admin/boundaries'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/components/campus-map', () => ({ CampusMap: () => null }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ locations: vi.fn(async () => f.locations), zones: vi.fn(async () => []), saveZone: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-141', () => {
  test(
    'Test Case Description: Admin adds a no-fly zone "Gymnasium Roof" with a 120 m radius | ' +
      "Expected Result: The zone is saved and 'Zone added.' is shown",
    async () => {
      renderPage(<FlightBoundaries />, '/admin/routes/no-fly-zones')
      fireEvent.click(await screen.findByRole('button', { name: 'Add' }))
      const dialog = await screen.findByRole('dialog')
      fireEvent.change(within(dialog).getByLabelText('Name'), { target: { value: 'Gymnasium Roof' } })
      fireEvent.change(within(dialog).getByLabelText(/Radius/), { target: { value: '120' } })
      fireEvent.click(within(dialog).getByRole('button', { name: 'Save zone' }))

      await vi.waitFor(() => expect(api.saveZone).toHaveBeenCalledWith(expect.objectContaining({ name: 'Gymnasium Roof' })))
      expect(await screen.findByText('Zone added.')).toBeInTheDocument()
    },
  )
})
