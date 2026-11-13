import { ArrowLeft, Ban, Check, ChefHat, CreditCard, LifeBuoy, PackageCheck, PlaneTakeoff, ReceiptText, Star, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { FlightPanel } from '@/components/flight-panel'
import { OrderChat } from '@/components/order-chat'
import { Money, OrderStatusBadge, OrderTimeline } from '@/components/orders'
import { Button } from '@/components/ui/button'
import { ConfirmDialog, Dialog } from '@/components/ui/dialog'
import { PageLoader } from '@/components/ui/loader'
import { Card, CardHeader, EmptyState, Field, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { markOrderReadyAndDispatch } from '@/lib/flight-sim'
import { api, type ExistingReviews } from '@/data/api'
import { effectiveStatus, formatDateTime, paymentLabel, shortId } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { Order } from '@/types'

export default function OrderDetail({ orderId }: { orderId?: string }) {
  const params = useParams()
  const id = orderId ?? params.id ?? ''
  const me = useMe()
  const navigate = useNavigate()
  const order = useQuery(() => api.order(id), [id], 4000)
  const locations = useQuery(() => api.locations())

  if (order.loading) return <PageLoader />
  const o = order.data
  const back = me.role === 'vendor' ? '/vendor/orders' : me.role === 'admin' ? '/admin/deliveries' : '/user/orders'
  if (!o) return <EmptyState title="Order not found" body="It may belong to another account." action={<Link to={back} className="font-semibold text-brand-ink hover:underline">Back to orders</Link>} />

  const status = effectiveStatus(o)
  const dropoff = locations.data?.find((l) => l.id === o.delivery_location_id)

  return (
    <div className="flex flex-col gap-6">
      <button type="button" onClick={() => navigate(back)} className="inline-flex w-fit items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
        <ArrowLeft aria-hidden className="size-4" /> Orders
      </button>

      <Card className="p-5 sm:p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="font-display text-2xl font-extrabold text-ink">{me.role === 'vendor' ? (o.customer_name ?? 'Customer') : (o.vendor_name ?? 'Order')}</h2>
              <OrderStatusBadge order={o} />
            </div>
            <p className="mt-1 text-sm text-ink-3">
              <span className="font-mono">{shortId(o.id)}</span> · Placed {formatDateTime(o.created_at)} · Drop-off at {dropoff?.name ?? '—'}
            </p>
          </div>
          <Actions order={o} />
        </div>
        {status !== 'cancelled' && status !== 'rejected' ? (
          <div className="mt-6">
            <OrderTimeline order={o} />
          </div>
        ) : (
          <p className="mt-5 rounded-xl bg-sunken px-4 py-3 text-sm text-ink-2">
            {status === 'rejected' ? 'The vendor could not take this order.' : `Cancelled${o.cancellation_reason ? ` by the ${o.cancellation_reason === 'weather' ? 'weather system' : o.cancellation_reason}` : ''}.`} {o.payment_status === 'refunded' ? 'Payment was refunded and stock restored.' : ''}
          </p>
        )}
      </Card>

      {me.role === 'user' && o.payment_method === 'xendit_online' && o.payment_status !== 'refunded' && (o.payment_status !== 'paid' || o.paid_at) ? <PaymentWaiting order={o} /> : null}

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_400px]">
        <div className="flex flex-col gap-6">
          {o.delivery ? <FlightPanel order={o} /> : null}
          <Card>
            <CardHeader title="Items" />
            <ul className="divide-y divide-line px-5 py-2">
              {o.items.map((i) => (
                <li key={i.id} className="flex items-center justify-between gap-4 py-3 text-sm">
                  <span className="text-ink">
                    <span className="font-semibold tabular-nums">{i.quantity}×</span> {i.product_name}
                  </span>
                  <Money value={i.subtotal} className="text-ink-2" />
                </li>
              ))}
            </ul>
            <dl className="space-y-1.5 px-5 pb-5 text-sm">
              <div className="flex justify-between text-ink-2"><dt>Subtotal</dt><dd><Money value={o.subtotal} /></dd></div>
              <div className="flex justify-between text-ink-2"><dt>Delivery fee</dt><dd><Money value={o.delivery_fee} /></dd></div>
              <div className="flex justify-between pt-1 text-base font-semibold text-ink"><dt>Total</dt><dd><Money value={o.total_amount} /></dd></div>
              <div className="flex justify-between pt-2 text-ink-3"><dt>Payment</dt><dd>{paymentLabel(o.payment_method)} · {o.payment_status}</dd></div>
            </dl>
            {o.notes ? <p className="mx-5 mb-5 rounded-xl bg-sunken px-4 py-3 text-sm text-ink-2"><span className="font-semibold text-ink">Note:</span> {o.notes}</p> : null}
          </Card>
        </div>
        <OrderChat order={o} />
      </div>
    </div>
  )
}

function Actions({ order: o }: { order: Order }) {
  const me = useMe()
  const status = effectiveStatus(o)
  const [busy, setBusy] = useState<string | null>(null)
  const [review, setReview] = useState(false)
  const existing = useQuery(() => (me.role === 'user' && effectiveStatus(o) === 'delivered' ? api.orderReviews(o.id) : Promise.resolve(null)), [o.id, o.order_status])

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

  if (me.role === 'vendor') {
    return (
      <div className="flex flex-wrap gap-2">
        {o.order_status === 'pending' ? (
          <>
            <ConfirmDialog trigger={<Button variant="outline" icon={<X aria-hidden className="size-4" />}>Reject</Button>} title="Reject this order?" body="The customer is refunded and the stock goes back to your inventory." confirmLabel="Reject order" onConfirm={() => run('reject', () => api.setOrderStatus(o.id, 'rejected'), 'Order rejected.')} />
            <Button loading={busy === 'confirm'} icon={<Check aria-hidden className="size-4" />} onClick={() => run('confirm', () => api.setOrderStatus(o.id, 'confirmed'), 'Order confirmed.')}>Confirm</Button>
          </>
        ) : null}
        {o.order_status === 'confirmed' ? <Button loading={busy === 'prep'} icon={<ChefHat aria-hidden className="size-4" />} onClick={() => run('prep', () => api.setOrderStatus(o.id, 'preparing'), 'Marked as preparing.')}>Start preparing</Button> : null}
        {o.order_status === 'preparing' ? <Button loading={busy === 'ready'} icon={<PlaneTakeoff aria-hidden className="size-4" />} onClick={() => run('ready', () => markOrderReadyAndDispatch(api, o.id), 'Ready for drone pickup.')}>Ready for drone pickup</Button> : null}
      </div>
    )
  }

  if (me.role === 'user') {
    const cancellable = ['pending', 'confirmed', 'preparing'].includes(o.order_status)
    const reviewed = !!existing.data && (!!existing.data.store || Object.keys(existing.data.products).length > 0)
    return (
      <div className="flex flex-wrap gap-2">
        {cancellable ? <ConfirmDialog trigger={<Button variant="outline" icon={<Ban aria-hidden className="size-4" />}>Cancel order</Button>} title="Cancel this order?" body="You can cancel until the order is ready for drone pickup. Payment is refunded and stock restored." confirmLabel="Cancel order" onConfirm={() => run('cancel', () => api.cancelOrder(o.id), 'Order cancelled.')} /> : null}
        {status === 'delivered' ? <Button variant="secondary" icon={<Star aria-hidden className="size-4" />} onClick={() => setReview(true)}>{reviewed ? 'Edit your review' : 'Rate this order'}</Button> : null}
        <Link to={`/user/orders/${o.id}/receipt`} className="inline-flex h-11 items-center gap-2 rounded-xl px-4 text-sm font-semibold text-ink-2 hover:bg-sunken hover:text-ink">
          <ReceiptText aria-hidden className="size-4" /> View receipt
        </Link>
        <Link to={`/user/help?orderId=${o.id}${o.delivery ? `&deliveryId=${o.delivery.id}` : ''}`} className={cn('inline-flex h-11 items-center gap-2 rounded-xl px-4 text-sm font-semibold text-ink-2 hover:bg-sunken hover:text-ink')}>
          <LifeBuoy aria-hidden className="size-4" /> Report a problem
        </Link>
        {review ? <ReviewDialog order={o} existing={existing.data ?? null} onOpenChange={setReview} /> : null}
      </div>
    )
  }

  return o.delivery ? (
    <Link to={`/admin/deliveries/details?id=${o.delivery.id}`} className="inline-flex h-11 items-center gap-2 rounded-xl bg-surface-2 px-4 text-sm font-semibold text-ink shadow-sm">
      <PackageCheck aria-hidden className="size-4" /> Delivery logs
    </Link>
  ) : null
}

/**
 * online_payment_waiting_screen.dart: a 15-minute invoice window counted from
 * order creation, reopen (or regenerate) the Xendit page, and live status from
 * the order poll plus realtime. Shown until the payment settles.
 */
function PaymentWaiting({ order: o }: { order: Order }) {
  const [now, setNow] = useState(() => Date.now())
  const [busy, setBusy] = useState(false)
  const pending = o.payment_status === 'pending' && o.order_status !== 'cancelled'
  useEffect(() => {
    if (!pending) return
    const id = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(id)
  }, [pending])
  const left = Math.max(0, 900 - Math.floor((now - new Date(o.created_at).getTime()) / 1000))
  const state = o.payment_status === 'paid' ? 'paid' : o.payment_status === 'failed' || o.order_status === 'cancelled' ? 'failed' : o.payment_status === 'expired' || left === 0 ? 'expired' : 'pending'
  if (state === 'paid' && o.paid_at && now - new Date(o.paid_at).getTime() > 10 * 60_000) return null

  async function open() {
    setBusy(true)
    try {
      const url = o.payment_invoice_url || (await api.startOnlinePayment(o.id))
      window.open(url, '_blank', 'noopener')
    } catch (e) {
      toast(errorMessage(e) || 'Unable to open checkout portal.', 'error')
    } finally {
      setBusy(false)
    }
  }

  const copy = {
    pending: ['Waiting for Payment', 'Complete your payment in the Xendit checkout window. This page updates once it is verified.'],
    paid: ['Payment Confirmed!', 'Your online payment was received and verified.'],
    expired: ['Payment Expired', 'The 15-minute payment window closed before the payment went through.'],
    failed: ['Payment Failed', 'This order was cancelled and no payment was processed.'],
  }[state]
  return (
    <Card className={cn('flex flex-col gap-4 p-5 sm:flex-row sm:items-center', state === 'pending' && 'ring-1 ring-brand/40')}>
      <span className={cn('grid size-11 shrink-0 place-items-center rounded-2xl', state === 'paid' ? 'bg-success-bg text-success' : state === 'pending' ? 'bg-brand/12 text-brand-ink' : 'bg-danger-bg text-danger')}>
        <CreditCard aria-hidden className="size-5" />
      </span>
      <div className="min-w-0 flex-1" aria-live="polite">
        <p className="font-semibold text-ink">{copy[0]}</p>
        <p className="mt-0.5 text-sm text-ink-2">{copy[1]}</p>
      </div>
      {state === 'pending' ? (
        <div className="flex flex-wrap items-center gap-3">
          <span className="font-mono text-sm font-semibold text-brand-ink tabular-nums">Expires in {String(Math.floor(left / 60)).padStart(2, '0')}:{String(left % 60).padStart(2, '0')}</span>
          <Button loading={busy} icon={<CreditCard aria-hidden className="size-4" />} onClick={open}>{busy ? 'Opening checkout…' : 'Reopen payment page'}</Button>
        </div>
      ) : null}
    </Card>
  )
}

function Stars({ value, onChange, label }: { value: number; onChange: (n: number) => void; label: string }) {
  return (
    <fieldset>
      <legend className="sr-only">{label}</legend>
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((n) => (
          <label key={n} className="cursor-pointer">
            <input type="radio" name={label} value={n} checked={value === n} onChange={() => onChange(n)} className="peer sr-only" />
            <Star aria-hidden className={cn('size-7 transition-transform duration-150 peer-focus-visible:scale-110 active:scale-[0.96]', n <= value ? 'fill-[#F0A03C] text-[#F0A03C]' : 'text-line')} />
            <span className="sr-only">{n} star{n > 1 ? 's' : ''}</span>
          </label>
        ))}
      </div>
    </fieldset>
  )
}

/**
 * order_review_dialog.dart: rate the store and, optionally, each product.
 * Existing ratings load in so they can be edited; at least one is required.
 */
function ReviewDialog({ order, existing, onOpenChange }: { order: Order; existing: ExistingReviews | null; onOpenChange: (v: boolean) => void }) {
  const [store, setStore] = useState(existing?.store?.rating ?? 0)
  const [comment, setComment] = useState(existing?.store?.comment ?? '')
  const [products, setProducts] = useState<Record<string, number>>(() => Object.fromEntries(Object.entries(existing?.products ?? {}).map(([k, v]) => [k, v.rating])))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const items = order.items.filter((i) => i.product_id)

  return (
    <Dialog open onOpenChange={onOpenChange} title="Rate this order" description="Reviews are optional and tied to this delivery.">
      <form
        onSubmit={async (e) => {
          e.preventDefault()
          const rated = Object.entries(products).filter(([, r]) => r > 0)
          if (!store && !rated.length) return setError('Rate the store or at least one product.')
          setBusy(true)
          setError(null)
          try {
            await api.submitReview(order.id, {
              storeRating: store || null,
              storeComment: comment,
              products: rated.map(([product_id, rating]) => ({ product_id, rating })),
            })
            invalidate()
            toast('Thanks for the review.')
            onOpenChange(false)
          } catch (err) {
            setError(errorMessage(err))
          } finally {
            setBusy(false)
          }
        }}
        className="flex flex-col gap-5"
      >
        <div>
          <p className="text-sm font-medium text-ink">{order.vendor_name ?? 'Store'}</p>
          <div className="mt-2"><Stars value={store} onChange={setStore} label="Store rating" /></div>
        </div>
        <Field label="Comment" hint="Optional.">{(p) => <Textarea {...p} value={comment} onChange={(e) => setComment(e.target.value)} maxLength={500} />}</Field>
        {items.length ? (
          <div>
            <p className="text-sm font-medium text-ink">Rate individual products <span className="font-normal text-ink-3">(optional)</span></p>
            <ul className="mt-2 divide-y divide-line">
              {items.map((i) => (
                <li key={i.id} className="flex items-center justify-between gap-3 py-2.5">
                  <span className="text-sm text-ink-2">{i.product_name}</span>
                  <Stars value={products[i.product_id!] ?? 0} onChange={(n) => setProducts((p) => ({ ...p, [i.product_id!]: n }))} label={`${i.product_name} rating`} />
                </li>
              ))}
            </ul>
          </div>
        ) : null}
        {error ? <p role="alert" className="rounded-xl bg-danger-bg px-3 py-2 text-sm font-medium text-danger">{error}</p> : null}
        <Button type="submit" loading={busy}>{existing?.store || Object.keys(existing?.products ?? {}).length ? 'Update review' : 'Submit review'}</Button>
      </form>
    </Dialog>
  )
}
