import * as DialogPrimitive from '@radix-ui/react-dialog'
import { motion, useReducedMotion } from 'motion/react'
import { Bell, LogOut, Menu, Moon, ShieldCheck, Sun, X } from 'lucide-react'
import { useEffect, useLayoutEffect, useMemo, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth, useMe } from '@/auth/auth'
import { Logo } from '@/components/brand'
import { IconButton } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/ui/dialog'
import { Avatar } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { cartCount, useCart } from '@/lib/cart'
import { effectiveStatus } from '@/lib/format'
import { useQuery } from '@/lib/store'
import { setTheme, useTheme } from '@/lib/theme'
import { cn } from '@/lib/utils'
import type { Role } from '@/types'
import { BackendSync } from './backend-sync'
import { extraTitles, navFor, type BadgeKey } from './nav'

const roleLabel: Record<Role, string> = { user: 'Customer', vendor: 'Vendor', admin: 'Admin' }

function useBadges(role: Role): Partial<Record<BadgeKey, number>> {
  const cart = useCart()
  const orders = useQuery(() => api.orders(), [], 20_000)
  const notes = useQuery(() => api.notifications(), [], 20_000)
  const reports = useQuery(() => (role === 'admin' ? api.reports() : Promise.resolve([])), [role], 30_000)
  const users = useQuery(() => (role === 'admin' ? api.users() : Promise.resolve([])), [role], 30_000)

  return useMemo(() => {
    const o = orders.data ?? []
    const active = o.filter((x) => !['delivered', 'cancelled', 'rejected'].includes(effectiveStatus(x))).length
    return {
      cart: cartCount(cart),
      activeOrders: active,
      unread: (notes.data ?? []).filter((n) => !n.is_read).length,
      // Same counts the vendor dock shows: orders waiting on the vendor.
      vendorAction: o.filter((x) => ['pending', 'confirmed', 'preparing'].includes(x.order_status)).length,
      pendingDeliveries: o.filter((x) => x.delivery && ['pending', 'assigning', 'in_transit'].includes(x.delivery.status)).length,
      openReports: (reports.data ?? []).filter((r) => r.status === 'open').length,
      pendingVendors: (users.data ?? []).filter((u) => u.vendor_status === 'pending').length,
    }
  }, [cart, orders.data, notes.data, reports.data, users.data])
}

export function PortalLayout({ role }: { role: Role }) {
  const me = useMe()
  const location = useLocation()
  const [drawer, setDrawer] = useState(false)
  const badges = useBadges(role)
  const theme = useTheme()
  const reduce = useReducedMotion()
  const groups = navFor[role]

  // The app paints every admin screen dark whatever the theme says; the web
  // console does the same, including dialogs portalled to <body>.
  useLayoutEffect(() => {
    if (role !== 'admin') return
    const root = document.documentElement
    const prev = root.dataset.theme
    root.dataset.theme = 'dark'
    return () => {
      root.dataset.theme = prev ?? 'light'
    }
  }, [role])

  useEffect(() => setDrawer(false), [location.pathname])

  const title = useMemo(() => {
    const path = location.pathname
    for (const [re, t] of extraTitles) if (re.test(path)) return t
    const items = groups.flatMap((g) => g.items)
    const hit = items.find((i) => (i.end ? path === i.to : path.startsWith(i.to))) ?? items[0]!
    return hit.title ?? hit.label
  }, [location.pathname, groups])

  useEffect(() => {
    document.title = `${title} · AeroDrop`
  }, [title])

  const notificationsPath = role === 'admin' ? '/admin/notifications' : role === 'vendor' ? '/vendor/notifications' : '/user/notifications'

  const sidebar = <SidebarContent role={role} badges={badges} />

  return (
    <div className="min-h-dvh bg-bg text-ink lg:grid lg:grid-cols-[272px_minmax(0,1fr)]">
      <BackendSync role={role} />
      <a href="#main" className="sr-only z-50 rounded-lg bg-surface px-3 py-2 focus:not-sr-only focus:fixed focus:top-3 focus:left-3">
        Skip to content
      </a>

      <aside aria-label={`${roleLabel[role]} navigation`} className="sticky top-0 hidden h-dvh flex-col bg-bg shadow-[1px_0_0_var(--line)] lg:flex">
        {sidebar}
      </aside>

      <DialogPrimitive.Root open={drawer} onOpenChange={setDrawer}>
        <DialogPrimitive.Portal>
          <DialogPrimitive.Overlay className="fixed inset-0 z-40 bg-black/60 data-[state=closed]:animate-[fade-out_150ms_ease-in] data-[state=open]:animate-[fade-in_200ms_ease-out] lg:hidden" />
          <DialogPrimitive.Content
            aria-label={`${roleLabel[role]} navigation`}
            className="fixed inset-y-0 left-0 z-50 flex w-[min(300px,86vw)] flex-col bg-surface pb-[env(safe-area-inset-bottom)] shadow-lg focus:outline-none data-[state=closed]:animate-[drawer-out_180ms_ease-in] data-[state=open]:animate-[drawer-in_260ms_cubic-bezier(0.16,1,0.3,1)] lg:hidden"
          >
            <DialogPrimitive.Title className="sr-only">Navigation</DialogPrimitive.Title>
            <DialogPrimitive.Description className="sr-only">Pages in the {roleLabel[role].toLowerCase()} portal</DialogPrimitive.Description>
            <DialogPrimitive.Close aria-label="Close navigation" className="absolute top-4 right-3 grid size-10 place-items-center rounded-xl text-ink-3 hover:bg-sunken hover:text-ink">
              <X aria-hidden className="size-5" />
            </DialogPrimitive.Close>
            {sidebar}
          </DialogPrimitive.Content>
        </DialogPrimitive.Portal>
      </DialogPrimitive.Root>

      <div className="flex min-w-0 flex-col">
        <header className="sticky top-0 z-20 flex h-16 items-center gap-2 bg-bg/85 px-4 pt-[env(safe-area-inset-top)] backdrop-blur-md sm:px-6 lg:px-8">
          <IconButton label="Open navigation" className="-ml-2 lg:hidden" onClick={() => setDrawer(true)}>
            <Menu aria-hidden className="size-5" />
          </IconButton>
          <h1 className="min-w-0 flex-1 truncate font-display text-lg font-bold text-ink sm:text-xl">{title}</h1>
          {role === 'admin' ? (
            <span className="hidden items-center gap-1 rounded-lg bg-info-bg px-2.5 py-1 text-[11px] font-bold text-brand sm:inline-flex">
              <ShieldCheck aria-hidden className="size-3.5" /> ADMIN
            </span>
          ) : (
            <IconButton label={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
              {theme === 'dark' ? <Sun aria-hidden className="size-5" /> : <Moon aria-hidden className="size-5" />}
            </IconButton>
          )}
          <BellLink to={notificationsPath} count={badges.unread ?? 0} />
          <NavLink to={role === 'admin' ? `/admin/users/${me.id}` : role === 'vendor' ? '/vendor/profile' : '/user/profile'} aria-label="Your profile" className="ml-1 rounded-full">
            <Avatar name={me.full_name} src={me.avatar_url ?? me.business_logo_url} size={34} />
          </NavLink>
        </header>

        <main id="main" className="flex-1 px-4 pt-2 pb-16 sm:px-6 lg:px-8">
          <motion.div
            key={location.pathname}
            initial={reduce ? false : { opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.22, ease: [0, 0, 0.2, 1] }}
            className="mx-auto w-full max-w-7xl"
          >
            <Outlet />
          </motion.div>
        </main>
      </div>
    </div>
  )
}

function BellLink({ to, count }: { to: string; count: number }) {
  const navigate = useNavigate()
  return (
    <IconButton label="Notifications" badge={count} onClick={() => navigate(to)}>
      <Bell aria-hidden className="size-5" />
    </IconButton>
  )
}

function SidebarContent({ role, badges }: { role: Role; badges: Partial<Record<BadgeKey, number>> }) {
  const me = useMe()
  const { signOut } = useAuth()
  const navigate = useNavigate()
  const groups = navFor[role]

  return (
    <>
      <div className="flex h-16 shrink-0 items-center gap-2 px-5">
        <Logo to={groups[0]!.items[0]!.to} />
        <span className="rounded-md bg-sunken px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-ink-2 uppercase">{roleLabel[role]}</span>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-2">
        {groups.map((g) => (
          <div key={g.label} className="mb-5">
            <p className="px-3 pb-1.5 text-[11px] font-semibold tracking-wide text-ink-3 uppercase">{g.label}</p>
            <ul className="flex flex-col gap-0.5">
              {g.items.map((item) => {
                const count = item.badge ? (badges[item.badge] ?? 0) : 0
                return (
                  <li key={item.to}>
                    <NavLink
                      to={item.to}
                      end={item.end}
                      className={({ isActive }) =>
                        cn(
                          'group relative flex h-11 items-center gap-3 rounded-xl px-3 text-sm font-medium transition-colors duration-150',
                          isActive ? 'text-brand-ink' : 'text-ink-2 hover:bg-sunken hover:text-ink',
                        )
                      }
                    >
                      {({ isActive }) => (
                        <>
                          {isActive ? (
                            <motion.span
                              layoutId={`nav-active-${role}`}
                              aria-hidden
                              className="absolute inset-0 rounded-xl bg-info-bg"
                              transition={{ type: 'spring', stiffness: 500, damping: 38 }}
                            />
                          ) : null}
                          <item.icon aria-hidden className="relative size-[18px]" strokeWidth={isActive ? 2.2 : 1.8} />
                          <span className="relative flex-1">{item.label}</span>
                          {count > 0 ? (
                            <span className="relative grid min-w-5 place-items-center rounded-full bg-brand px-1.5 text-[11px] leading-5 font-bold text-on-brand tabular-nums">
                              {count > 99 ? '99+' : count}
                              <span className="sr-only"> pending</span>
                            </span>
                          ) : null}
                        </>
                      )}
                    </NavLink>
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
      </nav>

      <div className="m-3 flex items-center gap-3 rounded-2xl bg-sunken p-3">
        <Avatar name={me.full_name} src={me.avatar_url ?? me.business_logo_url} size={38} />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-ink">{role === 'vendor' ? (me.business_name ?? me.full_name) : me.full_name}</p>
          <p className="truncate text-xs text-ink-3">{me.email}</p>
        </div>
        <ConfirmDialog
          trigger={
            <IconButton label="Sign out" className="shrink-0">
              <LogOut aria-hidden className="size-[18px]" />
            </IconButton>
          }
          title="Sign out?"
          body="You will need your password and a new sign-in code to come back."
          confirmLabel="Sign out"
          onConfirm={async () => {
            await signOut()
            navigate('/sign-in', { replace: true })
          }}
        />
      </div>
    </>
  )
}

