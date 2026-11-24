import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import Fleet from '@/pages/admin/fleet'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/components/campus-map', () => ({ CampusMap: () => null }))
vi.mock('@/data/api', async () => { const f = await import('./fixtures'); void f; return { ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ drones: vi.fn(async () => f.drones), rechargeDrone: vi.fn(async () => undefined) }) } })

describe('Test Case ID: CASE-089', () => {
  test(
    'Test Case Description: Admin recharges drone DRN-002 (41% battery, at the hub) | ' +
      "Expected Result: DRN-002 is recharged and 'DRN-002 recharged to 100% and available.' is shown",
    async () => {
      renderPage(<Fleet />, '/admin/drones')
      expect(await screen.findByText('DRN-002')).toBeInTheDocument()

      const buttons = screen.getAllByRole('button', { name: /Recharge/ })
      fireEvent.click(buttons[buttons.length - 1])

      await vi.waitFor(() => expect(api.rechargeDrone).toHaveBeenCalledWith('drn2'))
      expect(await screen.findByText('DRN-002 recharged to 100% and available.')).toBeInTheDocument()
    },
  )
})
