import { ScrollText, Search, Truck } from 'lucide-react'
import { useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Money, OrderStatusBadge } from '@/components/orders'
import { PageLoader, Skeleton } from '@/components/ui/loader'
import { Card, CardHeader, EmptyState, Input } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { effectiveStatus, formatDateTime, shortId } from '@/lib/format'
import { useQuery } from '@/lib/store'
import type { Order } from '@/types'
import OrderDetail from '../shared/order-detail'

type Tab = 'all' | 'active' | 'waiting' | 'delivered' | 'cancelled'
const match: Record<Tab, (o: Order) => boolean> = {
  all: () => true,
  active: (o) => o.delivery?.status === 'in_transit' || (o.delivery?.status === 'assigning' && !!o.delivery.drone_id),
  waiting: (o) => !o.delivery || o.delivery.status === 'pending' || (o.delivery.status === 'assigning' && !o.delivery.drone_id),
  delivered: (o) => effectiveStatus(o) === 'delivered',
  cancelled: (o) => ['cancelled', 'rejected'].includes(effectiveStatus(o)),
}

export default function AdminDeliveries() {
  const orders = useQuery(() => api.orders(), [], 6000)
  const [tab, setTab] = useState<Tab>('all')
  const [q, setQ] = useState('')
  const all = orders.data ?? []
  const term = q.trim().toLowerCase()
  const shown = all.filter((o) => match[tab](o) && (!term || `${o.id} ${o.vendor_name} ${o.customer_name}`.toLowerCase().includes(term)))

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <AnimatedTabs
          label="Delivery status"
          value={tab}
          onChange={setTab}
          tabs={[
            { value: 'all', label: 'All' },
            { value: 'active', label: 'In flight', count: all.filter(match.active).length },
            { value: 'waiting', label: 'Before dispatch', count: all.filter(match.waiting).filter((o) => !['cancelled', 'rejected', 'delivered'].includes(effectiveStatus(o))).length },
            { value: 'delivered', label: 'Delivered' },
            { value: 'cancelled', label: 'Cancelled' },
          ]}
        />
        <div className="relative lg:w-72">
          <Search aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-ink-3" />
          <Input type="search" aria-label="Search orders" placeholder="Order ID, vendor or customer" value={q} onChange={(e) => setQ(e.target.value)} className="pl-10" />
        </div>
      </div>
      <Card className="overflow-hidden">
        {orders.loading ? (
          <div className="space-y-2 p-4">{[0, 1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-12" />)}</div>
        ) : shown.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[820px] text-sm">
              <thead className="text-left text-xs text-ink-3">
                <tr className="shadow-[inset_0_-1px_0_var(--line)]">
                  {['Order', 'Vendor', 'Customer', 'Placed', 'Total', 'Status'].map((h) => <th key={h} scope="col" className={`px-4 py-3 font-medium ${h === 'Total' ? 'text-right' : ''}`}>{h}</th>)}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {shown.map((o) => (
                  <tr key={o.id} className="hover:bg-sunken/50">
                    <td className="px-4 py-3">
                      <Link to={`/admin/deliveries/details?id=${o.delivery?.id ?? o.id}`} className="font-mono text-xs font-semibold text-brand-ink hover:underline">{shortId(o.id)}</Link>
                    </td>
                    <td className="px-4 py-3 text-ink">{o.vendor_name ?? '—'}</td>
                    <td className="px-4 py-3 text-ink-2">{o.customer_name ?? '—'}</td>
                    <td className="px-4 py-3 text-ink-2 tabular-nums">{formatDateTime(o.created_at)}</td>
                    <td className="px-4 py-3 text-right"><Money value={o.total_amount} /></td>
                    <td className="px-4 py-3"><OrderStatusBadge order={o} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState icon={<Truck aria-hidden className="size-5" />} title="No deliveries here" body={term ? 'Try another search.' : undefined} />
        )}
      </Card>
    </div>
  )
}

/** /admin/deliveries/details?id= accepts a delivery id or an order id. */
export function AdminDeliveryDetail() {
  const [params] = useSearchParams()
  const id = params.get('id') ?? ''
  const orders = useQuery(() => api.orders(), [])
  const order = orders.data?.find((o) => o.delivery?.id === id || o.id === id)
  const logs = useQuery(() => (order?.delivery ? api.statusLogs(order.delivery.id) : Promise.resolve([])), [order?.delivery?.id], 5000)

  if (orders.loading) return <PageLoader />
  if (!order) return <EmptyState title="Delivery not found" action={<Link to="/admin/deliveries" className="font-semibold text-brand-ink hover:underline">Back to deliveries</Link>} />

  return (
    <div className="flex flex-col gap-6">
      <OrderDetail orderId={order.id} />
      {order.delivery ? (
        <Card>
          <CardHeader title="Delivery status log" description="Every state change the system recorded for this flight." />
          <ol className="p-5">
            {(logs.data ?? []).map((l) => (
              <li key={l.id} className="relative flex gap-4 pb-5 last:pb-0">
                <span aria-hidden className="mt-1.5 size-2.5 shrink-0 rounded-full bg-brand ring-4 ring-info-bg" />
                <div>
                  <p className="text-sm font-semibold text-ink capitalize">{l.status.replace(/_/g, ' ')}</p>
                  {l.message ? <p className="text-sm text-ink-2">{l.message}</p> : null}
                  <p className="text-xs text-ink-3 tabular-nums">{formatDateTime(l.created_at)}</p>
                </div>
              </li>
            ))}
            {logs.data && !logs.data.length ? <li className="flex items-center gap-2 text-sm text-ink-3"><ScrollText aria-hidden className="size-4" />No log entries yet.</li> : null}
          </ol>
        </Card>
      ) : null}
    </div>
  )
}
