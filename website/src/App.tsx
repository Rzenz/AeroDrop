import { MotionConfig } from 'motion/react'
import { lazy, Suspense, type ReactNode } from 'react'
import { createBrowserRouter, Navigate, Outlet, RouterProvider } from 'react-router-dom'
import { AuthProvider, RequireRole } from '@/auth/auth'
import { PageLoader } from '@/components/ui/loader'
import { Toaster } from '@/components/ui/toast'
import { PortalLayout } from '@/layouts/portal-layout'
import Landing from '@/pages/landing'
import Legal, { NotFound } from '@/pages/legal'
import { CookieConsent } from '@/components/cookie-consent'
import type { Role } from '@/types'

// Every portal page is its own chunk, so the landing page stays light.
const About = lazy(() => import('@/pages/about'))
const Team = lazy(() => import('@/pages/team'))
const SignIn = lazy(() => import('@/pages/auth/sign-in'))
const SignUp = lazy(() => import('@/pages/auth/sign-up'))
const ForgotPassword = lazy(() => import('@/pages/auth/forgot-password'))
const AccountPending = lazy(() => import('@/pages/auth/account-pending'))
const AuthCallback = lazy(() => import('@/pages/auth/auth-callback'))
const CompleteProfile = lazy(() => import('@/pages/auth/complete-profile'))

const UserHome = lazy(() => import('@/pages/user/home'))
const Shop = lazy(() => import('@/pages/user/shop'))
const VendorPage = lazy(() => import('@/pages/user/vendor'))
const ProductPage = lazy(() => import('@/pages/user/product'))
const Cart = lazy(() => import('@/pages/user/cart'))
const Checkout = lazy(() => import('@/pages/user/checkout'))
const UserOrders = lazy(() => import('@/pages/user/orders'))
const Track = lazy(() => import('@/pages/user/track'))

const OrderDetail = lazy(() => import('@/pages/shared/order-detail'))
const Notifications = lazy(() => import('@/pages/shared/notifications'))
const Profile = lazy(() => import('@/pages/shared/profile'))
const Help = lazy(() => import('@/pages/shared/help'))
const SupportThread = lazy(() => import('@/pages/shared/support-thread'))

const VendorDashboard = lazy(() => import('@/pages/vendor/dashboard'))
const VendorProducts = lazy(() => import('@/pages/vendor/products'))
const VendorOrders = lazy(() => import('@/pages/vendor/orders'))

const AdminDashboard = lazy(() => import('@/pages/admin/dashboard'))
const AdminDeliveries = lazy(() => import('@/pages/admin/deliveries'))
const AdminDeliveryDetail = lazy(() => import('@/pages/admin/deliveries').then((m) => ({ default: m.AdminDeliveryDetail })))
const Fleet = lazy(() => import('@/pages/admin/fleet'))
const AdminUsers = lazy(() => import('@/pages/admin/users'))
const AdminUserDetail = lazy(() => import('@/pages/admin/user-detail'))
const AdminSupport = lazy(() => import('@/pages/admin/support'))
const Analytics = lazy(() => import('@/pages/admin/analytics'))
const ActivityLogs = lazy(() => import('@/pages/admin/activity'))
const AdminWeather = lazy(() => import('@/pages/admin/weather'))
const FlightBoundaries = lazy(() => import('@/pages/admin/boundaries'))
const AdminSettings = lazy(() => import('@/pages/admin/settings'))

const page = (el: ReactNode) => <Suspense fallback={<PageLoader />}>{el}</Suspense>

const portal = (role: Role) => (
  <RequireRole role={role}>
    <PortalLayout role={role} />
  </RequireRole>
)

function Root() {
  return (
    <AuthProvider>
      <Outlet />
      <Toaster />
      <CookieConsent />
    </AuthProvider>
  )
}

// Paths mirror the app's GoRouter routes (lib/config/router/app_router.dart).
const router = createBrowserRouter([
  {
    element: <Root />,
    children: [
      { path: '/', element: <Landing /> },
      { path: '/about', element: page(<About />) },
      { path: '/team', element: page(<Team />) },
      { path: '/sign-in', element: page(<SignIn />) },
      { path: '/login', element: <Navigate to="/sign-in" replace /> },
      { path: '/sign-up', element: page(<SignUp />) },
      { path: '/register', element: <Navigate to="/sign-up" replace /> },
      { path: '/forgot-password', element: page(<ForgotPassword />) },
      { path: '/account-pending', element: page(<AccountPending />) },
      { path: '/auth/callback', element: page(<AuthCallback />) },
      { path: '/complete-profile', element: page(<CompleteProfile />) },
      { path: '/privacy', element: <Legal page="privacy" /> },
      { path: '/terms', element: <Legal page="terms" /> },

      {
        path: '/user',
        element: portal('user'),
        children: [
          { index: true, element: page(<UserHome />) },
          { path: 'shop', element: page(<Shop />) },
          { path: 'vendors', element: <Navigate to="/user/shop" replace /> },
          { path: 'vendors/:id', element: page(<VendorPage />) },
          { path: 'products/:id', element: page(<ProductPage />) },
          { path: 'cart', element: page(<Cart />) },
          { path: 'checkout', element: page(<Checkout />) },
          { path: 'orders', element: page(<UserOrders />) },
          { path: 'history', element: <Navigate to="/user/orders" replace /> },
          { path: 'orders/:id', element: page(<OrderDetail />) },
          { path: 'track', element: page(<Track />) },
          { path: 'notifications', element: page(<Notifications />) },
          { path: 'profile', element: page(<Profile />) },
          { path: 'help', element: page(<Help />) },
          { path: 'help/:reportId', element: page(<SupportThread />) },
        ],
      },
      {
        path: '/vendor',
        element: portal('vendor'),
        children: [
          { index: true, element: page(<VendorDashboard />) },
          { path: 'products', element: page(<VendorProducts />) },
          { path: 'orders', element: page(<VendorOrders />) },
          { path: 'orders/:id', element: page(<OrderDetail />) },
          { path: 'notifications', element: page(<Notifications />) },
          { path: 'profile', element: page(<Profile />) },
          { path: 'help', element: page(<Help />) },
          { path: 'help/:reportId', element: page(<SupportThread />) },
        ],
      },
      {
        path: '/admin',
        element: portal('admin'),
        children: [
          { index: true, element: page(<AdminDashboard />) },
          { path: 'deliveries', element: page(<AdminDeliveries />) },
          { path: 'deliveries/details', element: page(<AdminDeliveryDetail />) },
          { path: 'drones', element: page(<Fleet />) },
          { path: 'missions', element: <Navigate to="/admin/drones" replace /> },
          { path: 'users', element: page(<AdminUsers />) },
          { path: 'users/:id', element: page(<AdminUserDetail />) },
          { path: 'support', element: page(<AdminSupport />) },
          { path: 'support/:reportId', element: page(<SupportThread />) },
          { path: 'analytics', element: page(<Analytics />) },
          { path: 'reports', element: page(<ActivityLogs />) },
          { path: 'weather', element: page(<AdminWeather />) },
          { path: 'routes/no-fly-zones', element: page(<FlightBoundaries />) },
          { path: 'settings', element: page(<AdminSettings />) },
          { path: 'notifications', element: page(<Notifications />) },
        ],
      },
      { path: '*', element: <NotFound /> },
    ],
  },
])

export default function App() {
  return (
    // Motion drops transform animations for users who ask for less motion.
    <MotionConfig reducedMotion="user">
      <RouterProvider router={router} />
    </MotionConfig>
  )
}
