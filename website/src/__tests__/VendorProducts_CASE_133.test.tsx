import { fireEvent, screen, within } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import VendorProducts from '@/pages/vendor/products'
import { api } from '@/data/api'
import { renderPage } from './helpers'

vi.mock('@/auth/auth', async () => {
  const vendor = (await import('./helpers')).profile({ id: 'kape', role: 'vendor', vendor_status: 'active', business_name: 'Kape Kanto' })
  return { useMe: () => vendor }
})
vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./helpers')).fakeApi({ saveProduct: vi.fn(async () => undefined) }) }))

describe('Test Case ID: CASE-133', () => {
  test(
    'Test Case Description: Vendor adds Caramel Macchiato (P135.00, stock 20, 380 g), which is within the drone payload | ' +
      "Expected Result: The product is saved and 'Product added.' is shown",
    async () => {
      renderPage(<VendorProducts />, '/vendor/products')
      fireEvent.click((await screen.findAllByRole('button', { name: /Add product/i }))[0])
      const dialog = await screen.findByRole('dialog')
      fireEvent.change(within(dialog).getByLabelText('Name'), { target: { value: 'Caramel Macchiato' } })
      fireEvent.change(within(dialog).getByLabelText('Price (₱)'), { target: { value: '135' } })
      fireEvent.change(within(dialog).getByLabelText('Stock'), { target: { value: '20' } })
      fireEvent.change(within(dialog).getByLabelText('Weight (grams)'), { target: { value: '380' } })
      fireEvent.click(within(dialog).getByRole('button', { name: 'Add product' }))

      await vi.waitFor(() => expect(api.saveProduct).toHaveBeenCalledTimes(1))
      expect(await screen.findByText('Product added.')).toBeInTheDocument()
    },
  )
})
