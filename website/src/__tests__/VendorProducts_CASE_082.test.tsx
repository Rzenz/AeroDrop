import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import VendorProducts from '@/pages/vendor/products'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const vendor = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto' })
  return { useMe: () => vendor }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi() }))

describe('Test Case ID: CASE-082', () => {
  test(
    'Test Case Description: Vendor adds a product weighing 900 g, over the drone payload | ' +
      "Expected Result: Product is not saved and 'One item can’t exceed the drone payload of 500 g.' is shown",
    async () => {
      renderPage(<VendorProducts />, '/vendor/products')
      fireEvent.click((await screen.findAllByRole('button', { name: /Add product/i }))[0])
      const dialog = await screen.findByRole('dialog')
      fireEvent.change(within(dialog).getByLabelText('Name'), { target: { value: 'Iced Mocha Bundle' } })
      fireEvent.change(within(dialog).getByLabelText('Price (₱)'), { target: { value: '250' } })
      fireEvent.change(within(dialog).getByLabelText('Stock'), { target: { value: '10' } })
      fireEvent.change(within(dialog).getByLabelText('Weight (grams)'), { target: { value: '900' } })
      fireEvent.click(within(dialog).getByRole('button', { name: 'Add product' }))

      expect(await within(dialog).findByText('One item can’t exceed the drone payload of 500 g.')).toBeInTheDocument()
      expect(api.saveProduct).not.toHaveBeenCalled()
    },
  )
})
