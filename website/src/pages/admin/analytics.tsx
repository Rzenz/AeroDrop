import { CheckCircle2, Download, Printer, Timer, Truck, Users, Wallet } from 'lucide-react'
import { useState } from 'react'
import { BarSeries, lastNDays, SegmentedBar, STATUS_COLORS } from '@/components/charts'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Money, StatTile } from '@/components/orders'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Card, CardHeader } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { effectiveStatus, formatPeso, shortId } from '@/lib/format'
import { useQuery } from '@/lib/store'

type Range = 'today' | '7d' | '30d'
const days: Record<Range, number> = { today: 1, '7d': 7, '30d': 30 }

export default function Analytics() {
  const orders = useQuery(() => api.orders())
  const users = useQuery(() => api.users())
  const [range, setRange] = useState<Range>('7d')

  const since = new Date()
  since.setHours(0, 0, 0, 0)
  since.setDate(since.getDate() - (days[range] - 1))
  const inRange = (orders.data ?? []).filter((o) => Date.parse(o.created_at) >= since.getTime())

  const status = (s: string[]) => inRange.filter((o) => s.includes(effectiveStatus(o))).length
  const delivered = inRange.filter((o) => effectiveStatus(o) === 'delivered')
  const cancelled = status(['cancelled', 'rejected'])
  const revenue = delivered.reduce((s, o) => s + o.total_amount, 0)
  const flights = delivered.map((o) => o.delivery).filter((d) => d?.delivery_started_at && d.delivery_completed_at).map((d) => (Date.parse(d!.delivery_completed_at!) - Date.parse(d!.delivery_started_at!)) / 1000)
  const avgFlight = flights.length ? flights.reduce((a, b) => a + b, 0) / flights.length : null
  const people = (users.data ?? []).filter((u) => u.role !== 'admin')

  const dayBuckets = lastNDays(Math.max(days[range], 7))
  const volume = dayBuckets.map((d) => ({ label: d.label, value: (orders.data ?? []).filter((o) => o.delivery && new Date(o.created_at).toDateString() === d.key).length }))

  const byVendor = new Map<string, { name: string; orders: number; revenue: number }>()
  delivered.forEach((o) => {
    const k = o.vendor_id ?? '?'
    const v = byVendor.get(k) ?? { name: o.vendor_name ?? 'Unknown', orders: 0, revenue: 0 }
    v.orders += 1
    v.revenue += o.subtotal
    byVendor.set(k, v)
  })
  const vendorRank = [...byVendor.values()].sort((a, b) => b.revenue - a.revenue)

  function exportCsv() {
    const rows = [['order_id', 'created_at', 'vendor', 'customer', 'status', 'payment', 'subtotal', 'delivery_fee', 'total']]
    inRange.forEach((o) => rows.push([o.id, o.created_at, o.vendor_name ?? '', o.customer_name ?? '', effectiveStatus(o), o.payment_method ?? '', String(o.subtotal), String(o.delivery_fee), String(o.total_amount)]))
    const csv = rows.map((r) => r.map((c) => `"${c.replace(/"/g, '""')}"`).join(',')).join('\n')
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
    const a = Object.assign(document.createElement('a'), { href: url, download: `aerodrop-analytics-${range}-${new Date().toISOString().slice(0, 10)}.csv` })
    a.click()
    URL.revokeObjectURL(url)
  }

  const loading = orders.loading
  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm text-ink-2">Real-time system telemetry and dispatch metrics</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <AnimatedTabs label="Date range" value={range} onChange={setRange} tabs={[{ value: 'today', label: 'Today' }, { value: '7d', label: '7 days' }, { value: '30d', label: '30 days' }]} />
          <Button variant="secondary" size="sm" icon={<Download aria-hidden className="size-4" />} onClick={exportCsv} disabled={!inRange.length}>CSV</Button>
          <Button variant="secondary" size="sm" icon={<Printer aria-hidden className="size-4" />} onClick={() => window.print()}>PDF</Button>
        </div>
      </div>

      <section aria-label="Totals" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <StatTile label="Total Deliveries" value={loading ? '–' : inRange.filter((o) => o.delivery).length} icon={<Truck />} />
        <StatTile label="Success Rate" value={delivered.length + cancelled ? `${Math.round((delivered.length / (delivered.length + cancelled)) * 100)}%` : '—'} hint={`${cancelled} cancelled or rejected`} icon={<CheckCircle2 />} />
        <StatTile label="Total Revenue" value={formatPeso(revenue)} hint="Simulated payments" icon={<Wallet />} />
        <StatTile label="Avg Flight Time" value={avgFlight ? `${Math.floor(avgFlight / 60)}m ${Math.round(avgFlight % 60)}s` : '—'} icon={<Timer />} />
        <StatTile label="Active Users" value={users.loading ? '–' : people.filter((u) => u.account_status === 'active').length} hint={`${people.filter((u) => u.account_status === 'suspended').length} suspended · ${people.filter((u) => u.account_status === 'deleted').length} deleted`} icon={<Users />} />
      </section>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
        <Card>
          <CardHeader title="Daily Dispatch Volume" description="Orders that reached a drone, per day" />
          <div className="p-5 pt-3">{loading ? <Skeleton className="h-60" /> : <BarSeries data={volume} name="Deliveries" />}</div>
        </Card>
        <Card>
          <CardHeader title="Deliveries by Status" description={`${inRange.length} orders in range`} />
          <div className="p-5">
            {loading ? (
              <Skeleton className="h-28" />
            ) : (
              <SegmentedBar
                segments={[
                  { label: 'Delivered', value: delivered.length, color: STATUS_COLORS.good },
                  { label: 'In progress', value: status(['in_transit', 'ready_for_delivery']), color: STATUS_COLORS.info },
                  { label: 'Before dispatch', value: status(['pending', 'confirmed', 'preparing']), color: STATUS_COLORS.warning },
                  { label: 'Cancelled', value: cancelled, color: STATUS_COLORS.neutral },
                ]}
              />
            )}
          </div>
        </Card>
      </div>

      <Card className="overflow-hidden">
        <CardHeader title="Vendor performance" description="Delivered orders in range" />
        <div className="overflow-x-auto p-2">
          <table className="w-full min-w-[520px] text-sm">
            <thead className="text-left text-xs text-ink-3">
              <tr>
                <th scope="col" className="px-3 py-2 font-medium">Vendor</th>
                <th scope="col" className="px-3 py-2 text-right font-medium">Orders</th>
                <th scope="col" className="px-3 py-2 text-right font-medium">Revenue</th>
                <th scope="col" className="w-1/3 px-3 py-2 font-medium"><span className="sr-only">Share</span></th>
              </tr>
            </thead>
            <tbody>
              {vendorRank.map((v) => (
                <tr key={v.name}>
                  <td className="px-3 py-2.5 font-medium text-ink">{v.name}</td>
                  <td className="px-3 py-2.5 text-right tabular-nums">{v.orders}</td>
                  <td className="px-3 py-2.5 text-right"><Money value={v.revenue} /></td>
                  <td className="px-3 py-2.5">
                    <div aria-hidden className="h-2 origin-left rounded-full bg-brand" style={{ transform: `scaleX(${v.revenue / (vendorRank[0]?.revenue || 1)})` }} />
                  </td>
                </tr>
              ))}
              {!vendorRank.length ? <tr><td colSpan={4} className="px-3 py-8 text-center text-ink-3">No delivered orders in this range.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </Card>

      <Card className="hidden overflow-hidden print:block">
        <CardHeader title="Orders in range" />
        <table className="w-full text-xs">
          <tbody>
            {inRange.map((o) => (
              <tr key={o.id}>
                <td className="px-3 py-1 font-mono">{shortId(o.id)}</td>
                <td className="px-3 py-1">{o.vendor_name}</td>
                <td className="px-3 py-1">{effectiveStatus(o)}</td>
                <td className="px-3 py-1 text-right">{formatPeso(o.total_amount)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}
