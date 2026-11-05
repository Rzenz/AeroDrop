import {
  BarChart3,
  Bell,
  CloudSun,
  Home,
  LayoutDashboard,
  LifeBuoy,
  Map,
  Navigation,
  Package,
  PlaneTakeoff,
  ReceiptText,
  ScrollText,
  Settings,
  ShoppingBag,
  ShoppingCart,
  Store,
  Truck,
  User,
  Users,
  type LucideIcon,
} from 'lucide-react'
import type { Role } from '@/types'

export type BadgeKey = 'cart' | 'activeOrders' | 'unread' | 'vendorAction' | 'pendingDeliveries' | 'openReports' | 'pendingVendors'

export interface NavItem {
  label: string
  to: string
  icon: LucideIcon
  badge?: BadgeKey
  /** Page title in the top bar when it differs from the label (the admin app bar's titles). */
  title?: string
  end?: boolean
}

export interface NavGroup {
  label: string
  items: NavItem[]
}

// Carried over from the app's shells, destination for destination:
//  - UserShell bottom nav: Home, Shop, [Cart FAB], Orders, Profile, plus the
//    Track and Notifications routes in the same shell.
//  - VendorShell dock: Home, Products, Orders, Alerts, Profile.
//  - AdminShell dock (Dashboard, Deliveries, Fleet, Users) and its fan menu
//    (Support, Analytics, Activity Logs, Weather, Flight Boundaries, Settings),
//    with the app bar's titles.
export const navFor: Record<Role, NavGroup[]> = {
  user: [
    {
      label: 'Order',
      items: [
        { label: 'Home', to: '/user', icon: Home, end: true },
        { label: 'Shop', to: '/user/shop', icon: ShoppingBag },
        { label: 'Cart', to: '/user/cart', icon: ShoppingCart, badge: 'cart' },
        { label: 'Orders', to: '/user/orders', icon: ReceiptText, badge: 'activeOrders' },
        { label: 'Track', to: '/user/track', icon: Navigation },
      ],
    },
    {
      label: 'Account',
      items: [
        { label: 'Notifications', to: '/user/notifications', icon: Bell, badge: 'unread' },
        { label: 'Profile', to: '/user/profile', icon: User },
        { label: 'Help & Support', to: '/user/help', icon: LifeBuoy },
      ],
    },
  ],
  vendor: [
    {
      label: 'Store',
      items: [
        { label: 'Home', to: '/vendor', icon: LayoutDashboard, end: true, title: 'Store Performance' },
        { label: 'Products', to: '/vendor/products', icon: Package },
        { label: 'Orders', to: '/vendor/orders', icon: ReceiptText, badge: 'vendorAction' },
        { label: 'Alerts', to: '/vendor/notifications', icon: Bell, badge: 'unread' },
      ],
    },
    {
      label: 'Account',
      items: [
        { label: 'Profile', to: '/vendor/profile', icon: Store, title: 'My Profile' },
        { label: 'Help & Support', to: '/vendor/help', icon: LifeBuoy },
      ],
    },
  ],
  admin: [
    {
      label: 'Operations',
      items: [
        { label: 'Dashboard', to: '/admin', icon: LayoutDashboard, end: true, title: 'Command Deck' },
        { label: 'Deliveries', to: '/admin/deliveries', icon: Truck, badge: 'pendingDeliveries' },
        { label: 'Fleet', to: '/admin/drones', icon: PlaneTakeoff, title: 'Drone Fleet' },
        { label: 'Users', to: '/admin/users', icon: Users, badge: 'pendingVendors', title: 'Users & Vendors' },
      ],
    },
    {
      label: 'More',
      items: [
        { label: 'Support', to: '/admin/support', icon: LifeBuoy, badge: 'openReports', title: 'Support & Inquiries' },
        { label: 'Analytics', to: '/admin/analytics', icon: BarChart3 },
        { label: 'Activity Logs', to: '/admin/reports', icon: ScrollText },
        { label: 'Weather', to: '/admin/weather', icon: CloudSun, title: 'Weather Controls' },
        { label: 'Flight Boundaries', to: '/admin/routes/no-fly-zones', icon: Map },
        { label: 'Settings', to: '/admin/settings', icon: Settings },
      ],
    },
  ],
}

/** Routes outside the sidebar that still need a title in the top bar. */
export const extraTitles: [RegExp, string][] = [
  [/^\/user\/vendors\//, 'Store'],
  [/^\/user\/products\//, 'Product'],
  [/^\/user\/checkout/, 'Checkout'],
  [/^\/(user|vendor)\/orders\/[^/]+/, 'Order Details'],
  [/^\/admin\/notifications/, 'Notifications'],
  [/^\/admin\/deliveries\/details/, 'Delivery Details'],
  [/^\/admin\/users\/[^/]+/, 'Account Details'],
]
