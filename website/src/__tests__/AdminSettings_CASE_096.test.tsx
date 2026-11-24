import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, test } from 'vitest'
import AdminSettings from '@/pages/admin/settings'
import { renderPage } from './helpers'

describe('Test Case ID: CASE-096', () => {
  test(
    'Test Case Description: Admin turns off Live Drone Telemetry in System Settings | ' +
      'Expected Result: The Live drone telemetry switch changes from on to off',
    () => {
      renderPage(<AdminSettings />, '/admin/settings')
      const toggle = screen.getByRole('switch', { name: 'Live drone telemetry' })
      expect(toggle).toBeChecked()

      fireEvent.click(toggle)

      expect(toggle).not.toBeChecked()
    },
  )
})
