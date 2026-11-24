import { render, screen } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { DropoffMapPicker } from '@/components/dropoff-map-picker'

const zone = { centerLatitude: 10.325152, centerLongitude: 123.953046, centerName: 'Campus Drone Hub', radiusMeters: 300 }

describe('Test Case ID: CASE-102', () => {
  test(
    'Test Case Description: Customer places a custom drop-off pin about 450 m from the Campus Drone Hub (limit 300 m) on the website | ' +
      'Expected Result: The pin is marked outside the delivery area and Confirm drop-off is disabled',
    () => {
      const onConfirm = vi.fn()
      render(<DropoffMapPicker zone={zone} initial={{ lat: 10.329194, lng: 123.953046, label: null }} onConfirm={onConfirm} onCancel={vi.fn()} />)

      expect(screen.getByText(/Outside the delivery area: \d+ m from Campus Drone Hub, and the limit is 300 m\./)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Confirm drop-off' })).toBeDisabled()
      expect(onConfirm).not.toHaveBeenCalled()
    },
  )
})
