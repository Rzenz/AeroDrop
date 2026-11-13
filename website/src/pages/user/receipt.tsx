import { ArrowLeft, CircleCheck, Printer, ReceiptText } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { Money } from '@/components/orders'
import { Button, ButtonLink } from '@/components/ui/button'
import { PageLoader, Spinner } from '@/components/ui/loader'
import { EmptyState, ErrorNote } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { effectiveStatus, formatDateTime, orderStatusMeta, paymentLabel, shortId } from '@/lib/format'
import { useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { Order } from '@/types'

/** Navigation state the checkout sets, so only a fresh order plays the print. */
export interface ReceiptLocationState {
  justPlaced?: boolean
}

type Stage = 'processing' | 'printing' | 'complete'

const STATUS: Record<Stage, string> = {
  processing: 'Processing your order',
  printing: 'Printing your receipt',
  complete: 'Order complete',
}

/** Same length as the app's ReceiptPrinter.feedDuration. */
const FEED_MS = 1750

const prefersReducedMotion = () => typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

/**
 * The printed record of one order, read from the stored order: every price
 * comes from order_items and the order row, never from the cart.
 *
 * Right after checkout the sheet feeds out of a printer, as in the app:
 * processing while the order loads, printing for the feed, then complete.
 * Opened any other way, or with reduced motion, it is simply already printed.
 */
export default function Receipt() {
  const { id = '' } = useParams()
  const me = useMe()
  const navigate = useNavigate()
  const location = useLocation()
  const [animate] = useState(() => (location.state as ReceiptLocationState | null)?.justPlaced === true && !prefersReducedMotion())

  const order = useQuery(() => api.order(id), [id])
  const locations = useQuery(() => api.locations())
  const o = order.data

  const [printed, setPrinted] = useState(!animate)
  const stage: Stage = printed ? 'complete' : o ? 'printing' : 'processing'

  useEffect(() => {
    if (printed || !o) return
    const t = window.setTimeout(() => {
      setPrinted(true)
      // Drop the flag so a reload or a return visit shows the finished receipt
      navigate(location.pathname, { replace: true, state: null })
    }, FEED_MS)
    return () => window.clearTimeout(t)
  }, [printed, o, navigate, location.pathname])

  if (order.loading && !animate) return <PageLoader />

  if (!order.loading && !o) {
    return order.error ? (
      <ErrorNote message={order.error} onRetry={order.reload} />
    ) : (
      <EmptyState
        icon={<ReceiptText aria-hidden className="size-5" />}
        title="Receipt not available"
        body="This order doesn't exist, or it belongs to another account."
        action={<ButtonLink to="/user/orders" variant="secondary">Back to orders</ButtonLink>}
      />
    )
  }

  const dropoff = o ? locations.data?.find((l) => l.id === o.delivery_location_id)?.name : undefined

  return (
    <div className="mx-auto flex w-full max-w-md flex-col items-center gap-5">
      <div className="flex w-full items-center justify-between gap-3 print:hidden">
        <Link to={o ? `/user/orders/${o.id}` : '/user/orders'} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
          <ArrowLeft aria-hidden className="size-4" /> Order
        </Link>
        <p role="status" aria-live="polite" className="inline-flex min-w-0 items-center gap-2 text-sm font-medium text-ink-2">
          {stage === 'complete' ? <CircleCheck aria-hidden className="size-4 shrink-0 text-success" /> : <Spinner size={14} className="shrink-0 text-brand" />}
          <span className="truncate">{STATUS[stage]}</span>
        </p>
      </div>

      {/* The printer: a slot the paper feeds out of */}
      <div className="w-full print:hidden">
        <div className="relative h-5 rounded-t-2xl rounded-b-md bg-surface-2 shadow-sm">
          <div className="absolute inset-x-4 bottom-1.5 h-1 rounded-full bg-ink/80 dark:bg-black" />
        </div>
      </div>

      <div className="-mt-6 w-full overflow-hidden px-3 pb-2 print:mt-0 print:overflow-visible print:p-0">
        {o && stage !== 'processing' ? (
          <div className={cn(animate && stage === 'printing' && 'receipt-feed')}>
            <ReceiptSheet order={o} customerName={me.full_name} customerPhone={me.phone_number} dropoff={dropoff} />
          </div>
        ) : (
          <div aria-hidden className="h-40" />
        )}
      </div>

      {stage === 'complete' && o ? (
        <div className="flex w-full flex-wrap justify-center gap-2 print:hidden">
          <Button variant="secondary" icon={<Printer aria-hidden className="size-4" />} onClick={() => window.print()}>
            Print
          </Button>
          <ButtonLink to={`/user/orders/${o.id}`} variant="primary">
            Track my order
          </ButtonLink>
        </div>
      ) : null}
    </div>
  )
}

function ReceiptSheet({ order: o, customerName, customerPhone, dropoff }: { order: Order; customerName?: string | null; customerPhone?: string | null; dropoff?: string }) {
  const grams = o.items.reduce((s, i) => s + (i.weight_grams ?? 0) * i.quantity, 0)
  const ref = `ORD-${shortId(o.id).slice(1)}`
  return (
    <article aria-label={`Receipt for order ${ref}`} className="receipt-paper receipt-print bg-surface px-5 pt-6 pb-9 text-ink shadow-md sm:px-6">
      <header className="text-center">
        <p className="font-display text-lg font-extrabold tracking-tight">AeroDrop</p>
        <p className="text-xs text-ink-3">Campus drone delivery receipt</p>
      </header>

      <dl className="mt-5 space-y-1.5 text-sm">
        <Line k="Vendor" v={o.vendor_name ?? '—'} />
        {customerName ? <Line k="Customer" v={customerName} /> : null}
        {customerPhone ? <Line k="Phone" v={customerPhone} /> : null}
        <Line k="Drop-off" v={dropoff ?? '—'} />
        <Line k="Status" v={orderStatusMeta[effectiveStatus(o)].label} />
      </dl>

      <Rule />

      <ul className="space-y-2 text-sm">
        {o.items.map((i) => (
          <li key={i.id} className="flex items-start justify-between gap-3">
            <span className="min-w-0 break-words">
              <span className="block text-ink">{i.product_name}</span>
              <span className="block text-xs text-ink-3 tabular-nums">
                {i.quantity} × <Money value={i.unit_price} />
              </span>
            </span>
            <Money value={i.subtotal} className="shrink-0 text-ink" />
          </li>
        ))}
      </ul>

      <Rule />

      <dl className="space-y-1.5 text-sm">
        <Line k="Subtotal" v={<Money value={o.subtotal} />} />
        <Line k="Delivery fee" v={<Money value={o.delivery_fee} />} />
        <div className="flex items-baseline justify-between gap-3 pt-1">
          <dt className="font-semibold">Total</dt>
          <dd><Money value={o.total_amount} className="font-display text-xl font-bold" /></dd>
        </div>
        <Line k="Cargo weight" v={`${grams} g (${(grams / 1000).toFixed(2)} kg)`} />
      </dl>

      <Rule />

      <dl className="space-y-1.5 text-sm">
        <Line k="Order" v={<span className="font-mono">{ref}</span>} />
        <Line k="Paid with" v={paymentLabel(o.payment_method)} />
        {o.notes ? <Line k="Order note" v={o.notes} /> : null}
        <Line k="Date" v={formatDateTime(o.created_at)} />
      </dl>

      <p className="mt-6 text-center text-xs text-ink-3">Thank you for flying with AeroDrop.</p>
    </article>
  )
}

function Line({ k, v }: { k: string; v: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <dt className="shrink-0 text-ink-3">{k}</dt>
      <dd className="min-w-0 text-right break-words text-ink">{v}</dd>
    </div>
  )
}

function Rule() {
  return <hr className="my-4 border-0 border-t border-dashed border-line" />
}
