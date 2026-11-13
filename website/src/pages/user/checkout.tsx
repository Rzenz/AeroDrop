import { CreditCard, Globe, Smartphone } from 'lucide-react'
import { useMemo, useRef, useState, type FormEvent } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { Money } from '@/components/orders'
import { Button } from '@/components/ui/button'
import { PageLoader } from '@/components/ui/loader'
import { Card, Field, Input, Select, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { weatherMeta } from '@/components/weather-card'
import { api, type OrderQuote } from '@/data/api'
import { clearVendor, groupByVendor, useCart } from '@/lib/cart'
import { MAX_TRIPS, tripsForWeight } from '@/lib/fees'
import { isHub } from '@/lib/flight'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { PaymentMethod } from '@/types'

const methods: { value: PaymentMethod; label: string; body: string; icon: typeof Globe }[] = [
  { value: 'xendit_online', label: 'Pay online (GCash or Card)', body: 'Pay on Xendit’s secure checkout page.', icon: Globe },
  { value: 'gcash_simulated', label: 'Simulated GCash', body: 'Marked as paid right away.', icon: Smartphone },
  { value: 'card_simulated', label: 'Simulated Card', body: 'Card details are checked and never stored.', icon: CreditCard },
]

const luhn = (n: string) => {
  const d = n.replace(/\D/g, '')
  if (d.length < 13) return false
  let sum = 0
  for (let i = 0; i < d.length; i++) {
    let x = Number(d[d.length - 1 - i])
    if (i % 2) x = x * 2 > 9 ? x * 2 - 9 : x * 2
    sum += x
  }
  return sum % 10 === 0
}

export default function Checkout() {
  const me = useMe()
  const navigate = useNavigate()
  const items = useCart()
  const groups = groupByVendor(items)
  const locations = useQuery(() => api.locations())
  const weather = useQuery(() => api.weather())

  const [dropoff, setDropoff] = useState(me.campus_location_id ?? '')
  const [notes, setNotes] = useState('')
  const [method, setMethod] = useState<PaymentMethod>('gcash_simulated') // checkout_screen.dart defaults to GCash
  const [card, setCard] = useState({ number: '', expiry: '', cvc: '' })
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  // Placing an order empties the cart; don't bounce to /user/cart on the way to the order.
  const placedRef = useRef(false)

  const locs = useMemo(() => locations.data ?? [], [locations.data])
  const safety = weather.data?.safety_status
  const grounded = safety === 'grounded'

  // One order per vendor. Each is priced by the server (quote_order_fee), the
  // same function place_order charges with. Nothing here computes a price, and
  // a failed quote blocks the order instead of falling back to a local figure.
  const cartKey = groups.map((g) => `${g.vendorId}:${g.items.map((i) => `${i.productId}x${i.quantity}`).join(',')}`).join('|')
  const quoteAll = () =>
    Promise.all(
      groups.map((g) =>
        api.quoteOrderFee({
          vendorId: g.vendorId,
          dropoffLocationId: dropoff,
          items: g.items.map((i) => ({ product_id: i.productId, quantity: i.quantity })),
        }),
      ),
    )
  // Re-quoted when the drop-off, the cart or the weather changes: the server
  // adds its caution surcharge then. useQuery keeps the last result while it
  // refetches, so each result carries the inputs it priced and is shown only
  // while they still match: never the previous drop-off's price.
  const quoteKey = `${dropoff}|${cartKey}|${safety ?? ''}`
  const quotes = useQuery<{ key: string; quotes: OrderQuote[] } | null>(
    () => (dropoff && groups.length ? quoteAll().then((q) => ({ key: quoteKey, quotes: q })) : Promise.resolve(null)),
    [quoteKey],
  )
  const quoted = dropoff && quotes.data?.key === quoteKey && quotes.data.quotes.length === groups.length ? quotes.data.quotes : null
  const quoteFailed = !!dropoff && !quoted && !!quotes.error

  if (!items.length && !placedRef.current) return <Navigate to="/user/cart" replace />
  if (locations.loading) return <PageLoader />

  const grand = quoted?.reduce((s, q) => s + q.totalAmount, 0)
  // A weight question, answered locally so the cart can warn without a request
  const tooHeavy = groups.some((g) => tripsForWeight(g.items.reduce((s, i) => s + i.weightGrams * i.quantity, 0) / 1000) > MAX_TRIPS)

  async function place(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!dropoff) return setError('Choose where the drone should drop your order.')
    if (grounded) return setError('Drones are grounded by weather. Try again when conditions improve.')
    if (tooHeavy) return setError(`One order is over the ${MAX_TRIPS}-trip weight limit. Adjust your cart first.`)
    if (method === 'card_simulated') {
      if (!luhn(card.number)) return setError('That card number is not valid.')
      if (!/^(0[1-9]|1[0-2])\/\d{2}$/.test(card.expiry)) return setError('Enter the expiry as MM/YY.')
      if (!/^\d{3,4}$/.test(card.cvc)) return setError('Enter the 3 or 4 digit CVC.')
    }
    setBusy(true)
    // A fresh quote rather than the one on screen: the server charges its
    // current figure, and weather can change while the page is open.
    let fresh: OrderQuote[]
    try {
      fresh = await quoteAll()
    } catch (err) {
      setBusy(false)
      return setError(`The delivery fee could not be calculated: ${errorMessage(err)} Your order was not placed.`)
    }
    const placed: string[] = []
    try {
      for (const [n, g] of groups.entries()) {
        const q = fresh[n]!
        const id = await api.placeOrder({
          vendorId: g.vendorId,
          dropoffLocationId: dropoff,
          // Ignored by the server since migration 31, which prices the order
          // itself; sent so the place_order signature stays unchanged.
          subtotal: q.subtotal,
          deliveryFee: q.deliveryFee,
          totalAmount: q.totalAmount,
          paymentMethod: method,
          notes: notes.trim() || undefined,
          items: g.items.map((i) => ({ product_id: i.productId, product_name: i.productName, quantity: i.quantity, unit_price: i.unitPrice })),
        })
        placed.push(id)
        placedRef.current = true
        clearVendor(g.vendorId)
      }
      invalidate()
      if (method === 'xendit_online' && placed.length === 1) {
        // Same flow as the app: open the hosted invoice, the webhook confirms it.
        try {
          const url = await api.startOnlinePayment(placed[0]!)
          window.open(url, '_blank', 'noopener')
          toast('Complete the payment in the new tab. Your order unlocks once it is confirmed.', 'info')
        } catch (payErr) {
          // The order exists; its page has a Pay now button to retry.
          toast(`${errorMessage(payErr)} You can retry from the order page.`, 'error')
        }
      } else {
        toast(placed.length > 1 ? `${placed.length} orders placed.` : 'Order placed. The vendor will confirm it shortly.')
      }
      // A single paid order prints its receipt, as the app does after a
      // simulated payment. Online payments still open the order page, where
      // the payment is tracked; several orders go to the list.
      if (placed.length === 1 && method !== 'xendit_online') {
        navigate(`/user/orders/${placed[0]}/receipt`, { replace: true })
      } else {
        navigate(placed.length === 1 ? `/user/orders/${placed[0]}` : '/user/orders', { replace: true })
      }
    } catch (err) {
      setError(errorMessage(err))
      if (placed.length) invalidate()
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={place} noValidate className="grid gap-6 lg:grid-cols-[1fr_360px]">
      <div className="flex flex-col gap-4">
        {weather.data && weather.data.safety_status !== 'safe' ? (
          <p role="status" className={cn('rounded-xl px-4 py-3 text-sm font-medium', weatherMeta[weather.data.safety_status].cls)}>
            Campus weather is {weatherMeta[weather.data.safety_status].label}. {weatherMeta[weather.data.safety_status].note}
          </p>
        ) : null}

        <Card className="p-5">
          <h2 className="font-semibold text-ink">Drop-off</h2>
          <div className="mt-4 grid gap-4">
            <Field label="Building" hint="The Campus Drone Hub is the drone’s base and can’t be a drop-off.">
              {(p) => (
                <Select {...p} value={dropoff} onChange={(e) => setDropoff(e.target.value)}>
                  <option value="">Choose your drop-off</option>
                  {locs.filter((l) => !isHub(l)).map((l) => (
                    <option key={l.id} value={l.id}>
                      {l.name}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label="Note for the vendor" hint="Optional.">{(p) => <Textarea {...p} value={notes} onChange={(e) => setNotes(e.target.value)} maxLength={300} placeholder="Less ice, please." />}</Field>
          </div>
        </Card>

        <Card className="p-5">
          <h2 className="font-semibold text-ink">Payment</h2>
          <fieldset className="mt-4 grid gap-3">
            <legend className="sr-only">Payment method</legend>
            {methods.map((m) => (
              <label
                key={m.value}
                className={cn(
                  'flex cursor-pointer items-start gap-3 rounded-xl p-4 shadow-[inset_0_0_0_1px_var(--line)] transition-shadow duration-150',
                  method === m.value && 'shadow-[inset_0_0_0_2px_var(--brand)]',
                )}
              >
                <input type="radio" name="method" value={m.value} checked={method === m.value} onChange={() => setMethod(m.value)} className="mt-1 accent-[var(--brand)]" />
                <m.icon aria-hidden className="mt-0.5 size-5 text-brand" />
                <span>
                  <span className="block font-medium text-ink">{m.label}</span>
                  <span className="block text-sm text-ink-3">{m.body}</span>
                </span>
              </label>
            ))}
          </fieldset>
          {method === 'card_simulated' ? (
            <div className="mt-4 grid gap-4 sm:grid-cols-[2fr_1fr_1fr]">
              <Field label="Card number" hint="Try 4242 4242 4242 4242.">{(p) => <Input {...p} inputMode="numeric" autoComplete="off" value={card.number} onChange={(e) => setCard({ ...card, number: e.target.value })} />}</Field>
              <Field label="Expiry">{(p) => <Input {...p} placeholder="MM/YY" autoComplete="off" value={card.expiry} onChange={(e) => setCard({ ...card, expiry: e.target.value })} />}</Field>
              <Field label="CVC">{(p) => <Input {...p} inputMode="numeric" autoComplete="off" value={card.cvc} onChange={(e) => setCard({ ...card, cvc: e.target.value })} />}</Field>
            </div>
          ) : null}
        </Card>
      </div>

      <aside className="lg:sticky lg:top-20 lg:self-start">
        <Card className="p-5">
          <h2 className="font-semibold text-ink">Order summary</h2>
          {groups.map((g, n) => {
            const q = quoted?.[n]
            // Labelled on the weight that was charged, which the server caps
            const kg = q ? Math.min(q.totalWeightGrams / 1000, MAX_TRIPS * 0.5) : 0
            return (
              <div key={g.vendorId} className="mt-4 rounded-xl bg-sunken p-3.5 text-sm">
                <p className="font-semibold text-ink">{g.vendorName}</p>
                {q ? (
                  <dl className="mt-2 space-y-1">
                    <Row k={`Items (${g.items.reduce((s, i) => s + i.quantity, 0)})`} v={q.subtotal} />
                    <Row k="Base fee" v={q.breakdown.base} muted />
                    {q.distanceKm > 0 ? <Row k={`Distance ${q.distanceKm.toFixed(2)} km${q.tripsRequired > 1 ? ` × ${q.tripsRequired}` : ''}`} v={q.breakdown.distance} muted /> : null}
                    <Row k={`Weight ${kg.toFixed(2)} kg`} v={q.breakdown.weight} muted />
                    {q.breakdown.extraTrip ? <Row k="Extra trip" v={q.breakdown.extraTrip} muted /> : null}
                    {q.breakdown.weather ? <Row k="Caution weather" v={q.breakdown.weather} muted /> : null}
                    <div className="flex justify-between border-t border-line pt-1.5 font-semibold text-ink">
                      <dt>Total</dt>
                      <dd><Money value={q.totalAmount} /></dd>
                    </div>
                  </dl>
                ) : (
                  <p className="mt-2 text-ink-3">
                    {!dropoff ? 'Choose a drop-off to see the delivery fee.' : quoteFailed ? 'Delivery fee unavailable.' : 'Calculating the delivery fee…'}
                  </p>
                )}
              </div>
            )
          })}
          <div className="mt-5 flex items-baseline justify-between">
            <span className="text-ink-2">To pay</span>
            {grand != null ? <Money value={grand} className="font-display text-2xl font-bold text-ink" /> : <span className="font-display text-2xl font-bold text-ink-3">—</span>}
          </div>
          {quoteFailed ? (
            <div role="alert" className="mt-4 flex items-start justify-between gap-3 rounded-xl bg-danger-bg px-3 py-2.5 text-sm font-medium text-danger">
              <span>The delivery fee could not be calculated: {quotes.error}</span>
              <button type="button" onClick={quotes.reload} className="shrink-0 font-semibold underline underline-offset-2">
                Retry
              </button>
            </div>
          ) : null}
          {error ? (
            <p role="alert" className="mt-4 rounded-xl bg-danger-bg px-3 py-2.5 text-sm font-medium text-danger">
              {error}
            </p>
          ) : null}
          <Button type="submit" size="lg" loading={busy} disabled={grounded || !quoted} className="mt-4 w-full">
            {method === 'xendit_online' ? 'Continue to payment' : 'Place order'}
          </Button>
          {method === 'xendit_online' && groups.length > 1 ? <p className="mt-2 text-xs text-ink-3">Online payment opens one invoice per order from each order’s page.</p> : null}
        </Card>
      </aside>
    </form>
  )
}

function Row({ k, v, muted }: { k: string; v: number; muted?: boolean }) {
  return (
    <div className={cn('flex justify-between', muted ? 'text-ink-3' : 'text-ink-2')}>
      <dt>{k}</dt>
      <dd><Money value={v} /></dd>
    </div>
  )
}
