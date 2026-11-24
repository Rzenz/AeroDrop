// Integration testing: each case starts in one module and checks the result in
// the next, through the real pages, auth guard and drone flight module, with
// one shared backend (./backend.ts).
import { fireEvent, screen, within } from '@testing-library/react'
import { beforeEach, describe, expect, test, vi } from 'vitest'
import { addToCart, cartStore } from '@/lib/cart'
import { resetBackend } from './backend'
import { api, as, customerOrders, db, delivery, dispatchedOrder, fly, openAs, order, preparingOrder, signInWith } from './flow'

vi.mock('@/data/api', async () => ({ ...(await import('@/data/auth-errors')), api: (await import('./backend')).backendApi }))
vi.mock('@/components/campus-map', () => ({ CampusMap: () => null }))
vi.mock('@/components/dropoff-map-picker', () => ({ DropoffMapPicker: () => null }))

beforeEach(() => {
  resetBackend()
  cartStore.set([])
})

const path = () => screen.getByTestId('path').textContent
const T = { timeout: 4000 }
const until = (fn: () => void) => vi.waitFor(fn, T)

describe('Test Case ID: INT-001', () => {
  test('Authentication -> User Home | Customer signs in with valid credentials | Home page greets Maria and lists the open vendors', async () => {
    openAs(null, '/sign-in')
    signInWith('maria.santos@uclm.edu.ph')
    await until(() => expect(path()).toBe('/user'))
    expect(await screen.findByText('Maria', {}, T)).toBeInTheDocument()
    expect(await screen.findByText('Kape Kanto', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-002', () => {
  test('Authentication -> Vendor Dashboard | Approved vendor signs in | Vendor dashboard of Kape Kanto opens', async () => {
    openAs(null, '/sign-in')
    signInWith('kapekanto@uclm.edu.ph')
    await until(() => expect(path()).toBe('/vendor'))
    expect(await screen.findByText('Kape Kanto', {}, T)).toBeInTheDocument()
    expect(screen.getByText('Total Gross Revenue')).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-003', () => {
  test('Authentication -> Admin Dashboard | Administrator signs in | Admin dashboard opens', async () => {
    openAs(null, '/sign-in')
    signInWith('admin@aerodrop.ph')
    await until(() => expect(path()).toBe('/admin'))
  })
})

describe('Test Case ID: INT-004', () => {
  test('Authentication -> Account Pending | Vendor whose application is not yet approved signs in | Application under review page is shown instead of the vendor portal', async () => {
    openAs(null, '/sign-in')
    signInWith('teahaus@uclm.edu.ph')
    await until(() => expect(path()).toBe('/account-pending'))
    expect(await screen.findByText('Application under review', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-005', () => {
  test('Admin Users -> Vendor Portal | Admin approves the Tea Haus application, then the vendor signs in | Tea Haus opens the vendor dashboard and is notified of the approval', async () => {
    openAs('admin', '/admin/users')
    fireEvent.click(await screen.findByRole('button', { name: 'Approve' }, T))
    await until(() => expect(db.current.users.find((u) => u.id === 'tea')!.vendor_status).toBe('active'))

    openAs(null, '/sign-in')
    signInWith('teahaus@uclm.edu.ph')
    await until(() => expect(path()).toBe('/vendor'))
    openAs('tea', '/vendor/notifications')
    expect(await screen.findByText('Vendor Application Approved', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-006', () => {
  test('Admin User Detail -> Authentication | Admin suspends Maria Santos, then she tries to sign in | Sign in is refused with the suspended-account message', async () => {
    openAs('admin', '/admin/users/maria')
    fireEvent.click(await screen.findByRole('button', { name: 'Suspend account' }, T))
    const confirm = await screen.findByRole('alertdialog', {}, T).catch(() => null)
    if (confirm) fireEvent.click(within(confirm).getAllByRole('button').at(-1)!)
    await until(() => expect(db.current.users.find((u) => u.id === 'maria')!.account_status).toBe('suspended'))

    openAs(null, '/sign-in')
    signInWith('maria.santos@uclm.edu.ph')
    expect(await screen.findByText('Your account has been suspended. Please contact the administrator.', {}, T)).toBeInTheDocument()
    expect(path()).toBe('/sign-in')
  })
})

describe('Test Case ID: INT-007', () => {
  test('Vendor Products -> Shop | Kape Kanto adds Caramel Macchiato (P135, 380 g) | The new product appears on the Kape Kanto store page for customers', async () => {
    openAs('kape', '/vendor/products')
    fireEvent.click((await screen.findAllByRole('button', { name: /Add product/i }, T))[0]!)
    const dialog = await screen.findByRole('dialog', {}, T)
    fireEvent.change(within(dialog).getByLabelText('Name'), { target: { value: 'Caramel Macchiato' } })
    fireEvent.change(within(dialog).getByLabelText('Price (₱)'), { target: { value: '135' } })
    fireEvent.change(within(dialog).getByLabelText('Stock'), { target: { value: '20' } })
    fireEvent.change(within(dialog).getByLabelText('Weight (grams)'), { target: { value: '380' } })
    fireEvent.click(within(dialog).getByRole('button', { name: 'Add product' }))
    await until(() => expect(db.current.products.some((p) => p.name === 'Caramel Macchiato')).toBe(true))

    openAs('maria', '/user/vendors/kape')
    expect(await screen.findByText('Caramel Macchiato', {}, T)).toBeInTheDocument()
    expect(screen.getByText('₱135.00')).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-008', () => {
  test('Vendor Products -> Shop | Kape Kanto switches Butter Croissant to unavailable | Butter Croissant is no longer listed on the store page', async () => {
    openAs('kape', '/vendor/products')
    fireEvent.click(await screen.findByLabelText('Butter Croissant available', {}, T))
    await until(() => expect(db.current.products.find((p) => p.id === 'croissant')!.is_active).toBe(false))

    openAs('maria', '/user/vendors/kape')
    expect(await screen.findByText('Iced Spanish Latte', {}, T)).toBeInTheDocument()
    expect(screen.queryByText('Butter Croissant')).not.toBeInTheDocument()
  })
})

describe('Test Case ID: INT-009', () => {
  test('Product -> Cart | Customer adds 2 x Iced Spanish Latte from the product page | Cart lists 2 x Iced Spanish Latte with a subtotal of P240.00', async () => {
    openAs('maria', '/user/products/latte')
    const plus = await screen.findByRole('button', { name: /Increase|more|\+/i }, T)
    fireEvent.click(plus)
    fireEvent.click(screen.getByRole('button', { name: /Add to cart/ }))

    openAs('maria', '/user/cart')
    expect(await screen.findByText('Iced Spanish Latte', {}, T)).toBeInTheDocument()
    expect(screen.getAllByText('₱240.00').length).toBeGreaterThan(0)
  })
})

describe('Test Case ID: INT-010', () => {
  test('Cart -> Checkout -> Orders | Customer places the cart order for the Maritime Building | Order is created, the receipt opens and the order is listed in My Orders', async () => {
    addToCart(db.current.products.find((p) => p.id === 'latte')!, 'Kape Kanto')
    openAs('maria', '/user/checkout')
    fireEvent.click(await screen.findByLabelText(/Simulated GCash/, {}, T))
    await screen.findAllByText('Total', {}, T)
    fireEvent.click(screen.getByRole('button', { name: 'Place order' }))
    await until(() => expect(path()).toMatch(/^\/user\/orders\/.+\/receipt$/))
    expect(db.current.orders).toHaveLength(1)
    expect(db.current.products.find((p) => p.id === 'latte')!.stock_quantity).toBe(23)

    openAs('maria', '/user/orders')
    expect(await screen.findByText('Kape Kanto', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-011', () => {
  test('Checkout -> Vendor Orders | Customer places an order with Kape Kanto | The order appears under New in the vendor orders with the customer name, and the vendor is notified', async () => {
    await customerOrders()
    openAs('kape', '/vendor/orders')
    expect(await screen.findByText('Maria Santos', {}, T)).toBeInTheDocument()
    openAs('kape', '/vendor/notifications')
    expect(await screen.findByText('New Order Received', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-012', () => {
  test('Vendor Orders -> Customer Notifications | Kape Kanto confirms the pending order | The customer receives "Order Confirmed" and the order shows as confirmed', async () => {
    const id = await customerOrders()
    openAs('kape', `/vendor/orders/${id}`)
    fireEvent.click(await screen.findByRole('button', { name: 'Confirm' }, T))
    await until(() => expect(order(id).order_status).toBe('confirmed'))

    openAs('maria', '/user/notifications')
    expect(await screen.findByText('Order Confirmed', {}, T)).toBeInTheDocument()
    expect(screen.getByText('The vendor has accepted your order.')).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-013', () => {
  test('Vendor Orders -> Customer Orders | Kape Kanto rejects the pending order | The customer sees the order as rejected and the payment refunded', async () => {
    const id = await customerOrders()
    openAs('kape', `/vendor/orders/${id}`)
    fireEvent.click(await screen.findByRole('button', { name: 'Reject' }, T))
    const confirm = await screen.findByRole('alertdialog', {}, T).catch(() => null)
    if (confirm) fireEvent.click(within(confirm).getAllByRole('button').at(-1)!)
    await until(() => expect(order(id).order_status).toBe('rejected'))
    expect(order(id).payment_status).toBe('refunded')

    openAs('maria', `/user/orders/${id}`)
    expect(await screen.findByText(/The vendor could not take this order\. Payment was refunded and stock restored\./, {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-014', () => {
  test('Vendor Orders -> Drone Dispatch | Kape Kanto marks the order being prepared as Ready for drone pickup | DRN-001 is assigned, the delivery is listed for the admin and the customer is notified', async () => {
    const id = await preparingOrder()
    openAs('kape', `/vendor/orders/${id}`)
    fireEvent.click(await screen.findByRole('button', { name: 'Ready for drone pickup' }, T))
    expect(await screen.findByText('Order is ready for delivery. DRN-001 dispatched for pickup.', {}, T)).toBeInTheDocument()
    expect(delivery(id).status).toBe('assigning')
    expect(db.current.drones[0]!.status).toBe('assigned')

    openAs('admin', '/admin/deliveries')
    expect((await screen.findAllByText(/DRN-001|Maria Santos|Kape Kanto/, {}, T)).length).toBeGreaterThan(0)
    openAs('maria', '/user/notifications')
    expect(await screen.findByText('Drone Dispatched to Vendor', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-015', () => {
  test('Drone Dispatch -> Delivery Tracking | DRN-001 flies to Kape Kanto and picks up the package | Pickup is confirmed, telemetry is recorded and Track shows the drone in flight to the Maritime Building', async () => {
    const id = await dispatchedOrder()
    await fly(() => delivery(id).status === 'in_transit' && delivery(id).progress > 0.2)
    expect(db.current.telemetry.length).toBeGreaterThan(0)
    expect(db.current.logs.some((l) => l.status === 'in_transit')).toBe(true)

    openAs('maria', '/user/track')
    expect((await screen.findAllByText(/In flight/, {}, T)).length).toBeGreaterThan(0)
    expect(screen.getByText('Maritime Building')).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-016', () => {
  test('Delivery Tracking -> Orders | DRN-001 reaches the Maritime Building | The delivery is completed, the order shows Delivered and the customer receives "Order Delivered"', async () => {
    const id = await dispatchedOrder()
    await fly(() => delivery(id).status === 'delivered')
    expect(order(id).order_status).toBe('delivered')

    openAs('maria', `/user/orders/${id}`)
    expect((await screen.findAllByText(/Delivered/, {}, T)).length).toBeGreaterThan(0)
    openAs('maria', '/user/notifications')
    expect(await screen.findByText('Order Delivered', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-017', () => {
  test('Delivery -> Drone Fleet | DRN-001 completes the delivery and flies back to the hub | The drone is Available again on the admin Drones page', async () => {
    const id = await dispatchedOrder()
    await fly(() => delivery(id).status === 'delivered' && db.current.drones[0]!.status === 'available')

    openAs('admin', '/admin/drones')
    expect(await screen.findByText('DRN-001', {}, T)).toBeInTheDocument()
    expect(screen.getByText('Available')).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-018', () => {
  test('Orders -> Ratings -> Store Page | Customer rates the delivered Kape Kanto order 5 stars with a comment | The review appears on the Kape Kanto store page with the customer name', async () => {
    const id = await dispatchedOrder()
    await fly(() => delivery(id).status === 'delivered')
    openAs('maria', `/user/orders/${id}`)
    fireEvent.click(await screen.findByRole('button', { name: /Rate this order/ }, T))
    const dialog = await screen.findByRole('dialog', {}, T)
    fireEvent.click(within(within(dialog).getByRole('group', { name: 'Store rating' })).getByLabelText('5 stars'))
    fireEvent.change(within(dialog).getByLabelText('Comment'), { target: { value: 'Still cold when it landed. Great service!' } })
    fireEvent.click(within(dialog).getByRole('button', { name: 'Submit review' }))
    await until(() => expect(db.current.reviews).toHaveLength(1))

    openAs('maria', '/user/vendors/kape')
    expect(await screen.findByText('Still cold when it landed. Great service!', {}, T)).toBeInTheDocument()
    expect(screen.getByText('Maria Santos')).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-019', () => {
  test('Order Chat (Customer) -> Order Chat (Vendor) | Customer messages Kape Kanto about the order | The vendor sees the message in the order chat', async () => {
    const id = await preparingOrder()
    openAs('maria', `/user/orders/${id}`)
    const box = await screen.findByPlaceholderText('Message Kape Kanto', {}, T)
    fireEvent.change(box, { target: { value: 'Please leave it with the guard at the lobby.' } })
    fireEvent.click(screen.getByRole('button', { name: 'Send message' }))
    await until(() => expect(db.current.messages).toHaveLength(1))

    openAs('kape', `/vendor/orders/${id}`)
    expect(await screen.findByText('Please leave it with the guard at the lobby.', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-020', () => {
  test('Help & Support -> Admin Support | Customer files a report "Drone landed at the wrong building" | The report is listed as open on the admin Support page', async () => {
    openAs('maria', '/user/help')
    fireEvent.click(await screen.findByRole('button', { name: 'New Report' }, T))
    fireEvent.change(screen.getByLabelText('Subject'), { target: { value: 'Drone landed at the wrong building' } })
    fireEvent.change(screen.getByLabelText('What happened?'), { target: { value: 'My order was dropped at Annex 2 instead of the Maritime Building.' } })
    fireEvent.click(screen.getByRole('button', { name: 'Send report' }))
    await until(() => expect(db.current.reports).toHaveLength(1))

    openAs('admin', '/admin/support')
    expect((await screen.findAllByText('Drone landed at the wrong building', {}, T)).length).toBeGreaterThan(0)
  })
})

describe('Test Case ID: INT-021', () => {
  test('Admin Support -> Help & Support | Admin resolves the open report | The customer sees the report as resolved and is notified', async () => {
    await as('maria', () => api.submitReport({ subject: 'Drone landed at the wrong building', message: 'My order was dropped at Annex 2 instead of the Maritime Building.', category: 'delivery_issue' }))
    openAs('admin', '/admin/support')
    fireEvent.click(await screen.findByRole('button', { name: 'Resolve' }, T))
    await until(() => expect(db.current.reports[0]!.status).toBe('resolved'))

    openAs('maria', '/user/help')
    expect((await screen.findAllByText('Resolved', {}, T)).length).toBeGreaterThan(0)
    openAs('maria', '/user/notifications')
    expect(await screen.findByText('Report Resolved', {}, T)).toBeInTheDocument()
  })
})

describe('Test Case ID: INT-022', () => {
  test('Admin Weather -> Checkout | Admin grounds the fleet, then the customer tries to place an order | The order is not placed and the grounded-weather message is shown', async () => {
    openAs('admin', '/admin/weather')
    const apply = await screen.findAllByRole('button', { name: 'Apply' }, T)
    fireEvent.click(apply[apply.length - 1]!)
    fireEvent.click(within(await screen.findByRole('alertdialog', {}, T)).getByRole('button', { name: 'Ground the fleet' }))
    await until(() => expect(db.current.weather.safety_status).toBe('grounded'))

    addToCart(db.current.products.find((p) => p.id === 'latte')!, 'Kape Kanto')
    openAs('maria', '/user/checkout')
    const place = await screen.findByRole('button', { name: 'Place order' }, T)
    expect(await screen.findByText(/New orders are paused until conditions improve\./, {}, T)).toBeInTheDocument()
    expect(place).toBeDisabled()
    fireEvent.click(place)
    expect(db.current.orders).toHaveLength(0)
  })
})

describe('Test Case ID: INT-023', () => {
  test('Admin Weather -> Drone Dispatch | The fleet is grounded and Kape Kanto marks an order ready | No drone is dispatched and "Flight dispatch blocked: Weather is grounded" is shown', async () => {
    const id = await preparingOrder()
    await as('admin', () => api.setWeatherOverride('grounded'))
    openAs('kape', `/vendor/orders/${id}`)
    fireEvent.click(await screen.findByRole('button', { name: 'Ready for drone pickup' }, T))
    expect(await screen.findByText(/Flight dispatch blocked: Weather is grounded/, {}, T)).toBeInTheDocument()
    expect(db.current.deliveries).toHaveLength(0)
    expect(db.current.drones[0]!.status).toBe('available')
  })
})
