// Renders the website's real routes (as in App.tsx) with the real AuthProvider
// and role guard, against the in-memory backend. The portal side bar is left
// out; every page, guard and redirect is the production one.
import { cleanup, render } from '@testing-library/react'
import type { ReactNode } from 'react'
import { MemoryRouter, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { AuthProvider, RequireRole } from '@/auth/auth'
import { Toaster } from '@/components/ui/toast'
import AccountPending from '@/pages/auth/account-pending'
import SignIn from '@/pages/auth/sign-in'
import AdminDashboard from '@/pages/admin/dashboard'
import AdminDeliveries from '@/pages/admin/deliveries'
import Fleet from '@/pages/admin/fleet'
import AdminSupport from '@/pages/admin/support'
import AdminUsers from '@/pages/admin/users'
import AdminUserDetail from '@/pages/admin/user-detail'
import AdminWeather from '@/pages/admin/weather'
import Help from '@/pages/shared/help'
import Notifications from '@/pages/shared/notifications'
import OrderDetail from '@/pages/shared/order-detail'
import SupportThread from '@/pages/shared/support-thread'
import Cart from '@/pages/user/cart'
import Checkout from '@/pages/user/checkout'
import Receipt from '@/pages/user/receipt'
import UserHome from '@/pages/user/home'
import UserOrders from '@/pages/user/orders'
import ProductPage from '@/pages/user/product'
import Shop from '@/pages/user/shop'
import Track from '@/pages/user/track'
import VendorPage from '@/pages/user/vendor'
import VendorDashboard from '@/pages/vendor/dashboard'
import VendorOrders from '@/pages/vendor/orders'
import VendorProducts from '@/pages/vendor/products'
import type { Role } from '@/types'

const portal = (role: Role) => <RequireRole role={role}><Outlet /></RequireRole>

/** Shows the current path, so a test can check where a redirect landed. */
function Where() {
  return <output data-testid="path">{useLocation().pathname}</output>
}

export function renderApp(path: string): ReturnType<typeof render> {
  cleanup()
  const tree: ReactNode = (
    <MemoryRouter initialEntries={[path]}>
      <AuthProvider>
        <Where />
        <Routes>
          <Route path="/sign-in" element={<SignIn />} />
          <Route path="/account-pending" element={<AccountPending />} />
          <Route path="/user" element={portal('user')}>
            <Route index element={<UserHome />} />
            <Route path="shop" element={<Shop />} />
            <Route path="vendors/:id" element={<VendorPage />} />
            <Route path="products/:id" element={<ProductPage />} />
            <Route path="cart" element={<Cart />} />
            <Route path="checkout" element={<Checkout />} />
            <Route path="orders" element={<UserOrders />} />
            <Route path="orders/:id" element={<OrderDetail />} />
            <Route path="orders/:id/receipt" element={<Receipt />} />
            <Route path="track" element={<Track />} />
            <Route path="notifications" element={<Notifications />} />
            <Route path="help" element={<Help />} />
            <Route path="help/:reportId" element={<SupportThread />} />
          </Route>
          <Route path="/vendor" element={portal('vendor')}>
            <Route index element={<VendorDashboard />} />
            <Route path="products" element={<VendorProducts />} />
            <Route path="orders" element={<VendorOrders />} />
            <Route path="orders/:id" element={<OrderDetail />} />
            <Route path="notifications" element={<Notifications />} />
          </Route>
          <Route path="/admin" element={portal('admin')}>
            <Route index element={<AdminDashboard />} />
            <Route path="deliveries" element={<AdminDeliveries />} />
            <Route path="drones" element={<Fleet />} />
            <Route path="users" element={<AdminUsers />} />
            <Route path="users/:id" element={<AdminUserDetail />} />
            <Route path="support" element={<AdminSupport />} />
            <Route path="support/:reportId" element={<SupportThread />} />
            <Route path="weather" element={<AdminWeather />} />
          </Route>
          <Route path="*" element={<p>Not found</p>} />
        </Routes>
        <Toaster />
      </AuthProvider>
    </MemoryRouter>
  )
  return render(<>{tree}</>)
}
