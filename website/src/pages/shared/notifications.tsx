import { Bell, CheckCheck, CloudSun, LifeBuoy, MessageCircle, Package, PlaneTakeoff, Store, BatteryLow } from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Card, EmptyState } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { timeAgo } from '@/lib/format'
import { invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { AppNotification, Role } from '@/types'

const iconFor = (t: string | null) => {
  if (!t) return Bell
  if (t.includes('message')) return MessageCircle
  if (t.includes('weather')) return CloudSun
  if (t.includes('support')) return LifeBuoy
  if (t.includes('battery') || t.includes('stuck')) return BatteryLow
  if (t.includes('vendor_application')) return Store
  if (t.includes('drone') || t.includes('transit') || t.includes('picked')) return PlaneTakeoff
  return Package
}

/** Port of notification_route.dart: where a tap on each type goes, per role. */
function routeFor(n: AppNotification, role: Role): string | null {
  const m = (n.metadata ?? {}) as Record<string, string | undefined>
  const t = n.notification_type ?? ''
  const base = role === 'vendor' ? '/vendor' : role === 'admin' ? '/admin' : '/user'
  if (t.startsWith('support_report')) return role === 'admin' ? '/admin/support' : `${base}/help`
  if (t === 'vendor_application') return role === 'admin' ? (m.user_id ? `/admin/users/${m.user_id}` : '/admin/users') : '/vendor'
  if (t.startsWith('weather')) return role === 'admin' ? '/admin/weather' : null
  if (t.startsWith('drone_')) return role === 'admin' ? '/admin/drones' : m.order_id ? `${base}/orders/${m.order_id}` : null
  if (t === 'low_stock' || t === 'stock_out') return role === 'vendor' ? '/vendor/products' : null
  if (m.order_id) return role === 'admin' ? '/admin/deliveries' : `${base}/orders/${m.order_id}`
  return null
}

export default function Notifications() {
  const me = useMe()
  const navigate = useNavigate()
  const q = useQuery(() => api.notifications(), [], 15_000)
  const [tab, setTab] = useState<'all' | 'unread'>('all')
  const all = q.data ?? []
  const unread = all.filter((n) => !n.is_read)
  const shown = tab === 'unread' ? unread : all

  async function open(n: AppNotification) {
    if (!n.is_read) await api.markNotificationRead(n.id).then(invalidate, () => undefined)
    const to = routeFor(n, me.role)
    if (to) navigate(to)
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <AnimatedTabs label="Filter notifications" value={tab} onChange={setTab} tabs={[{ value: 'all', label: 'All' }, { value: 'unread', label: 'Unread', count: unread.length }]} />
        <Button variant="ghost" size="sm" disabled={!unread.length} icon={<CheckCheck aria-hidden className="size-4" />} onClick={() => api.markAllNotificationsRead().then(invalidate)}>
          Mark all as read
        </Button>
      </div>
      <Card className="p-2">
        {q.loading ? (
          <div className="space-y-2 p-3">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-16" />)}</div>
        ) : shown.length ? (
          <ul>
            {shown.map((n) => {
              const Icon = iconFor(n.notification_type)
              return (
                <li key={n.id}>
                  <button type="button" onClick={() => open(n)} className="flex w-full items-start gap-4 rounded-xl px-3 py-3.5 text-left transition-colors duration-150 hover:bg-sunken">
                    <span className={cn('grid size-10 shrink-0 place-items-center rounded-xl', n.is_read ? 'bg-sunken text-ink-3' : 'bg-info-bg text-brand')}>
                      <Icon aria-hidden className="size-[18px]" />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-2">
                        <span className={cn('text-sm text-ink', !n.is_read && 'font-semibold')}>{n.title}</span>
                        {!n.is_read ? <span className="size-2 rounded-full bg-brand"><span className="sr-only">Unread</span></span> : null}
                      </span>
                      <span className="mt-0.5 block text-sm text-ink-2">{n.message}</span>
                    </span>
                    <span className="shrink-0 text-xs text-ink-3">{timeAgo(n.created_at)}</span>
                  </button>
                </li>
              )
            })}
          </ul>
        ) : (
          <EmptyState icon={<Bell aria-hidden className="size-5" />} title={tab === 'unread' ? 'You’re all caught up' : 'No notifications yet'} body="Order updates, messages and alerts land here." />
        )}
      </Card>
    </div>
  )
}
