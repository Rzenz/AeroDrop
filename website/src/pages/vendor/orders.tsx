import { Check, ChefHat, PlaneTakeoff, ReceiptText, X } from 'lucide-react'
import { useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { OrderStatusBadge } from '@/components/orders'
import { Button } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/ui/dialog'
import { Skeleton } from '@/components/ui/loader'
import { Card, EmptyState } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { markOrderReadyAndDispatch } from '@/lib/flight-sim'
import { api } from '@/data/api'
import { effectiveStatus, formatPeso, shortId, timeAgo } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import type { Order } from '@/types'

type Tab = 'pending' | 'preparing' | 'ready' | 'done'
const match: Record<Tab, (o: Order) => boolean> = {
  pending: (o) => o.order_status === 'pending',
  preparing: (o) => o.order_status === 'confirmed' || o.order_status === 'preparing',
  ready: (o) => effectiveStatus(o) === 'in_transit' || o.order_status === 'ready_for_delivery',
  done: (o) => ['delivered', 'cancelled', 'rejected'].includes(effectiveStatus(o)),
}

export default function VendorOrders() {
  const [params, setParams] = useSearchParams()
  const initial = (params.get('status') as Tab) || 'pending'
  const [tab, setTab] = useState<Tab>(initial in match ? initial : 'pending')
  const orders = useQuery(() => api.orders(), [], 8000)
  const all = orders.data ?? []
  const shown = all.filter(match[tab])

  return (
    <div className="flex flex-col gap-5">
      <AnimatedTabs
        label="Order status"
        value={tab}
        onChange={(t) => {
          setTab(t)
          setParams({ status: t }, { replace: true })
        }}
        tabs={[
          { value: 'pending', label: 'New', count: all.filter(match.pending).length },
          { value: 'preparing', label: 'Preparing', count: all.filter(match.preparing).length },
          { value: 'ready', label: 'With drone', count: all.filter(match.ready).length },
          { value: 'done', label: 'Completed' },
        ]}
      />
      {orders.loading ? (
        <div className="grid gap-4 md:grid-cols-2">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-44 rounded-2xl" />)}</div>
      ) : shown.length ? (
        <ul className="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
          {shown.map((o) => <OrderCard key={o.id} order={o} />)}
        </ul>
      ) : (
        <Card>
          <EmptyState icon={<ReceiptText aria-hidden className="size-5" />} title={tab === 'pending' ? 'No new orders' : 'Nothing here'} body={tab === 'pending' ? 'New orders appear the moment a customer places them.' : undefined} />
        </Card>
      )}
    </div>
  )
}

function OrderCard({ order: o }: { order: Order }) {
  const [busy, setBusy] = useState<string | null>(null)
  async function run(key: string, fn: () => Promise<unknown>, ok: string) {
    setBusy(key)
    try {
      const msg = await fn()
      invalidate()
      toast(typeof msg === 'string' ? msg : ok)
    } catch (e) {
      toast(errorMessage(e), 'error')
    } finally {
      setBusy(null)
    }
  }
  return (
    <li>
      <Card className="flex h-full flex-col p-5">
        <div className="flex items-start justify-between gap-3">
          <div>
            <Link to={`/vendor/orders/${o.id}`} className="font-semibold text-ink hover:underline">{o.customer_name ?? 'Customer'}</Link>
            <p className="text-xs text-ink-3"><span className="font-mono">{shortId(o.id)}</span> · {timeAgo(o.created_at)}</p>
          </div>
          <OrderStatusBadge order={o} />
        </div>
        <ul className="mt-4 flex-1 space-y-1 text-sm">
          {o.items.map((i) => (
            <li key={i.id} className="flex justify-between gap-3 text-ink-2">
              <span><b className="text-ink tabular-nums">{i.quantity}×</b> {i.product_name}</span>
              <span className="tabular-nums">{formatPeso(i.subtotal)}</span>
            </li>
          ))}
        </ul>
        {o.notes ? <p className="mt-3 rounded-lg bg-sunken px-3 py-2 text-xs text-ink-2">“{o.notes}”</p> : null}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          {o.unread_messages ? <Link to={`/vendor/orders/${o.id}`} className="mr-auto text-xs font-semibold text-brand-ink">{o.unread_messages} new message{o.unread_messages > 1 ? 's' : ''}</Link> : <span className="mr-auto font-semibold text-ink tabular-nums">{formatPeso(o.total_amount)}</span>}
          {o.order_status === 'pending' ? (
            <>
              <ConfirmDialog trigger={<Button variant="ghost" size="sm" icon={<X aria-hidden className="size-4" />}>Reject</Button>} title="Reject this order?" body="The customer is refunded and the stock goes back to your inventory." confirmLabel="Reject order" onConfirm={() => run('reject', () => api.setOrderStatus(o.id, 'rejected'), 'Order rejected.')} />
              <Button size="sm" loading={busy === 'confirm'} icon={<Check aria-hidden className="size-4" />} onClick={() => run('confirm', () => api.setOrderStatus(o.id, 'confirmed'), 'Order confirmed.')}>Confirm</Button>
            </>
          ) : null}
          {o.order_status === 'confirmed' ? <Button size="sm" loading={busy === 'prep'} icon={<ChefHat aria-hidden className="size-4" />} onClick={() => run('prep', () => api.setOrderStatus(o.id, 'preparing'), 'Marked as preparing.')}>Start preparing</Button> : null}
          {o.order_status === 'preparing' ? <Button size="sm" loading={busy === 'ready'} icon={<PlaneTakeoff aria-hidden className="size-4" />} onClick={() => run('ready', () => markOrderReadyAndDispatch(api, o.id), 'Ready for pickup.')}>Ready for pickup</Button> : null}
        </div>
      </Card>
    </li>
  )
}
