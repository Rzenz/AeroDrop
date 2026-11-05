import { ChefHat, Clock, PackagePlus, Plane, Receipt, ShoppingBag, TrendingUp, Wallet } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { BarSeries, lastNDays } from '@/components/charts'
import { OrderRow, StatTile } from '@/components/orders'
import { ButtonLink } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Card, CardHeader, EmptyState } from '@/components/ui/primitives'
import { WeatherCard } from '@/components/weather-card'
import { api } from '@/data/api'
import { effectiveStatus, formatPeso } from '@/lib/format'
import { useQuery } from '@/lib/store'

export default function VendorDashboard() {
  const me = useMe()
  const orders = useQuery(() => api.orders(), [], 10_000)
  const products = useQuery(() => api.products({ vendorId: me.id, includeInactive: true }), [me.id])

  const all = orders.data ?? []
  const delivered = all.filter((o) => effectiveStatus(o) === 'delivered')
  const revenue = delivered.reduce((s, o) => s + o.subtotal, 0)
  const aov = delivered.length ? revenue / delivered.length : 0
  const byHour = new Map<number, number>()
  all.forEach((o) => byHour.set(new Date(o.created_at).getHours(), (byHour.get(new Date(o.created_at).getHours()) ?? 0) + 1))
  const peak = [...byHour.entries()].sort((a, b) => b[1] - a[1])[0]
  const fmtHour = (h: number) => new Date(2000, 0, 1, h).toLocaleTimeString('en-PH', { hour: 'numeric' })

  const days = lastNDays(7)
  const weekly = days.map((d) => ({
    label: new Date(d.key).toLocaleDateString('en-PH', { weekday: 'short' }),
    value: delivered.filter((o) => new Date(o.created_at).toDateString() === d.key).reduce((s, o) => s + o.subtotal, 0),
  }))

  const count = (s: string) => all.filter((o) => o.order_status === s).length
  const tiles = [
    { key: 'pending', label: 'Pending', icon: Clock, n: count('pending') },
    { key: 'preparing', label: 'Preparing', icon: ChefHat, n: count('confirmed') + count('preparing') },
    { key: 'ready', label: 'Ready', icon: Plane, n: all.filter((o) => o.order_status === 'ready_for_delivery' || o.delivery?.status === 'in_transit').length },
  ]

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm text-ink-3">Vendor</p>
          <h2 className="font-display text-2xl font-extrabold text-ink">{me.business_name}</h2>
        </div>
        <ButtonLink to="/vendor/products?new=1" icon={<PackagePlus aria-hidden className="size-4" />}>
          Add Product
        </ButtonLink>
      </div>

      <section aria-label="Orders needing action" className="grid gap-4 sm:grid-cols-3">
        {tiles.map((t) => (
          <Link key={t.key} to={`/vendor/orders?status=${t.key}`} className="group flex items-center gap-4 rounded-2xl bg-surface p-5 shadow-md transition-transform duration-150 ease-out active:scale-[0.98]">
            <span className="grid size-12 place-items-center rounded-2xl bg-info-bg text-brand">
              <t.icon aria-hidden className="size-5" />
            </span>
            <span className="flex-1">
              <span className="block text-sm text-ink-2">{t.label}</span>
              <span className="font-display text-2xl font-bold text-ink tabular-nums">{orders.loading ? '–' : t.n}</span>
            </span>
          </Link>
        ))}
      </section>

      <section aria-label="Store Performance" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile label="Total Gross Revenue" value={formatPeso(revenue)} hint={`${delivered.length} delivered orders`} icon={<Wallet />} />
        <StatTile label="Average Order Value" value={delivered.length ? formatPeso(aov) : '—'} hint={delivered.length ? 'Items only, before delivery fees' : 'Not enough orders yet'} icon={<Receipt />} />
        <StatTile label="Listed Products" value={products.data ? products.data.filter((p) => p.is_active).length : '–'} hint={products.data ? `${products.data.filter((p) => p.stock_quantity <= 5).length} low on stock` : undefined} icon={<ShoppingBag />} />
        <StatTile label="Peak Ordering Hour" value={peak ? fmtHour(peak[0]) : '—'} hint={peak ? `${peak[1]} orders placed at this hour` : 'Not enough orders yet'} icon={<TrendingUp />} />
      </section>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
        <Card>
          <CardHeader title="Performance Analytics" description="Delivered revenue, last 7 days" />
          <div className="p-5 pt-3">{orders.loading ? <Skeleton className="h-60" /> : <BarSeries data={weekly} name="Revenue" format={(v) => (v >= 1000 ? `₱${(v / 1000).toFixed(1)}k` : `₱${Math.round(v)}`)} />}</div>
        </Card>
        <WeatherCard />
      </div>

      <Card>
        <CardHeader title="Recent Orders" action={<Link to="/vendor/orders" className="text-sm font-semibold text-brand-ink hover:underline">See all</Link>} />
        <div className="p-2">
          {all.length ? (
            <ul>{all.slice(0, 5).map((o) => <OrderRow key={o.id} order={o} to={`/vendor/orders/${o.id}`} perspective="vendor" />)}</ul>
          ) : orders.loading ? (
            <Skeleton className="m-3 h-40" />
          ) : (
            <EmptyState title="No orders received yet" body="New orders appear here the moment a customer places them." action={<ButtonLink to="/vendor/products" variant="secondary">Review your products</ButtonLink>} />
          )}
        </div>
      </Card>
    </div>
  )
}
