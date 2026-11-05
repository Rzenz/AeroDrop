import { Check, ChevronRight, MessageCircle } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { effectiveStatus, formatPeso, orderStatusMeta, shortId, timeAgo } from '@/lib/format'
import { cn } from '@/lib/utils'
import type { Order, OrderStatus } from '@/types'
import { Badge, Card } from './ui/primitives'

export function OrderStatusBadge({ order }: { order: Order }) {
  const s = effectiveStatus(order)
  const meta = orderStatusMeta[s]
  return (
    <Badge tone={meta.tone} dot>
      {meta.label}
    </Badge>
  )
}

/** Hero-number tile (dataviz: a single figure is a stat tile, not a chart). */
export function StatTile({ label, value, hint, icon, className }: { label: string; value: ReactNode; hint?: ReactNode; icon?: ReactNode; className?: string }) {
  return (
    <Card className={cn('p-5', className)}>
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm text-ink-2">{label}</p>
        {icon ? <span className="grid size-8 place-items-center rounded-lg bg-info-bg text-brand [&_svg]:size-4">{icon}</span> : null}
      </div>
      <p className="mt-3 font-display text-2xl font-bold text-ink">{value}</p>
      {hint ? <p className="mt-1 text-xs text-ink-3">{hint}</p> : null}
    </Card>
  )
}

export function OrderRow({ order, to, perspective }: { order: Order; to: string; perspective: 'user' | 'vendor' | 'admin' }) {
  const counterpart = perspective === 'user' ? order.vendor_name : order.customer_name
  const items = order.items.reduce((s, i) => s + i.quantity, 0)
  return (
    <li>
      <Link to={to} className="group flex items-center gap-4 rounded-xl px-3 py-3 transition-colors duration-150 hover:bg-sunken">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span className="font-semibold text-ink">{counterpart ?? 'Order'}</span>
            <span className="font-mono text-xs text-ink-3">{shortId(order.id)}</span>
            {order.unread_messages > 0 ? (
              <span className="inline-flex items-center gap-1 text-xs font-semibold text-brand">
                <MessageCircle aria-hidden className="size-3.5" />
                {order.unread_messages} new
              </span>
            ) : null}
          </div>
          <p className="mt-0.5 truncate text-sm text-ink-3">
            {items} item{items === 1 ? '' : 's'} · {order.items.map((i) => i.product_name).join(', ')}
          </p>
        </div>
        <div className="hidden text-right sm:block">
          <p className="font-semibold text-ink tabular-nums">{formatPeso(order.total_amount)}</p>
          <p className="text-xs text-ink-3">{timeAgo(order.created_at)}</p>
        </div>
        <OrderStatusBadge order={order} />
        <ChevronRight aria-hidden className="size-4 shrink-0 text-ink-3 transition-transform duration-150 group-hover:translate-x-0.5" />
      </Link>
    </li>
  )
}

const flow: OrderStatus[] = ['pending', 'confirmed', 'preparing', 'ready_for_delivery', 'in_transit', 'delivered']
const flowLabel: Partial<Record<OrderStatus, string>> = {
  pending: 'Placed',
  confirmed: 'Confirmed',
  preparing: 'Preparing',
  ready_for_delivery: 'Ready',
  in_transit: 'In flight',
  delivered: 'Delivered',
}

/** Horizontal stepper of the delivery workflow from the README. */
export function OrderTimeline({ order }: { order: Order }) {
  const s = effectiveStatus(order)
  if (s === 'cancelled' || s === 'rejected') return null
  const at = Math.max(0, flow.indexOf(s === 'ready_for_delivery' && order.delivery?.status === 'in_transit' ? 'in_transit' : s))
  return (
    <ol className="grid grid-cols-6 gap-1" aria-label="Order progress">
      {flow.map((step, i) => {
        const done = i < at || s === 'delivered'
        const current = i === at && s !== 'delivered'
        return (
          <li key={step} className="flex flex-col items-center gap-2 text-center" aria-current={current ? 'step' : undefined}>
            <div className="flex w-full items-center">
              <span className={cn('h-0.5 flex-1', i === 0 ? 'opacity-0' : done || current ? 'bg-brand' : 'bg-line')} />
              <span
                className={cn(
                  'grid size-6 shrink-0 place-items-center rounded-full text-[11px] font-bold',
                  done ? 'bg-brand text-on-brand' : current ? 'bg-info-bg text-brand ring-2 ring-brand' : 'bg-sunken text-ink-3',
                )}
              >
                {done ? <Check aria-hidden className="size-3.5" strokeWidth={3} /> : i + 1}
              </span>
              <span className={cn('h-0.5 flex-1', i === flow.length - 1 ? 'opacity-0' : done ? 'bg-brand' : 'bg-line')} />
            </div>
            <span className={cn('text-[11px] leading-tight sm:text-xs', current ? 'font-semibold text-ink' : 'text-ink-3')}>{flowLabel[step]}</span>
          </li>
        )
      })}
    </ol>
  )
}

/** Determinate progress; scaleX keeps it on the compositor. */
export function ProgressBar({ value, className, label }: { value: number; className?: string; label: string }) {
  const pct = Math.round(Math.min(1, Math.max(0, value)) * 100)
  return (
    <div role="progressbar" aria-label={label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} className={cn('h-2 overflow-hidden rounded-full bg-sunken', className)}>
      <div className="h-full origin-left rounded-full bg-brand transition-transform duration-700 ease-linear" style={{ transform: `scaleX(${pct / 100})` }} />
    </div>
  )
}

export function Money({ value, className }: { value: number; className?: string }) {
  return <span className={cn('tabular-nums', className)}>{formatPeso(value)}</span>
}
