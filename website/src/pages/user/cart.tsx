import { Minus, Plus, ShoppingCart, Trash2 } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Money } from '@/components/orders'
import { ButtonLink, IconButton } from '@/components/ui/button'
import { Card, EmptyState, ProductArt } from '@/components/ui/primitives'
import { groupByVendor, removeFromCart, setQuantity, useCart } from '@/lib/cart'
import { MAX_PAYLOAD_KG, MAX_TRIPS, tripsForWeight } from '@/lib/fees'

export default function Cart() {
  const items = useCart()
  const groups = groupByVendor(items)
  const subtotal = items.reduce((s, i) => s + i.unitPrice * i.quantity, 0)

  if (!items.length) {
    return (
      <Card>
        <EmptyState icon={<ShoppingCart aria-hidden className="size-5" />} title="Your cart is empty" body="Add something from a campus vendor and it will wait here." action={<ButtonLink to="/user/shop">Browse vendors</ButtonLink>} />
      </Card>
    )
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_340px]">
      <div className="flex flex-col gap-4">
        {groups.map((g) => {
          const kg = g.items.reduce((s, i) => s + i.weightGrams * i.quantity, 0) / 1000
          const trips = tripsForWeight(kg)
          return (
            <Card key={g.vendorId}>
              <div className="flex items-center justify-between gap-3 px-5 pt-5">
                <Link to={`/user/vendors/${g.vendorId}`} className="font-semibold text-ink hover:underline">
                  {g.vendorName}
                </Link>
                <span className={`text-xs tabular-nums ${trips > MAX_TRIPS ? 'font-semibold text-danger' : 'text-ink-3'}`}>
                  {kg.toFixed(2)} kg · {trips} trip{trips === 1 ? '' : 's'}
                </span>
              </div>
              {trips > MAX_TRIPS ? (
                <p className="mx-5 mt-3 rounded-xl bg-danger-bg px-3 py-2 text-sm text-danger">
                  Too heavy for one order. The limit is {MAX_TRIPS} trips ({(MAX_PAYLOAD_KG * MAX_TRIPS).toFixed(1)} kg). Remove some items or split it.
                </p>
              ) : null}
              <ul className="divide-y divide-line px-5 py-2">
                {g.items.map((i) => (
                  <li key={i.productId} className="flex items-center gap-4 py-3">
                    <div className="size-14 shrink-0 overflow-hidden rounded-xl">
                      <ProductArt name={i.productName} src={i.imageUrl} className="text-base" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-medium text-ink">{i.productName}</p>
                      <p className="text-sm text-ink-3 tabular-nums">
                        <Money value={i.unitPrice} /> · {i.weightGrams} g
                      </p>
                    </div>
                    <div className="flex items-center rounded-xl bg-sunken p-0.5">
                      <IconButton label={`Decrease ${i.productName}`} className="size-8" onClick={() => setQuantity(i.productId, i.quantity - 1)}>
                        <Minus aria-hidden className="size-3.5" />
                      </IconButton>
                      <span className="w-7 text-center text-sm font-semibold tabular-nums">{i.quantity}</span>
                      <IconButton label={`Increase ${i.productName}`} className="size-8" disabled={i.quantity >= i.stock} onClick={() => setQuantity(i.productId, i.quantity + 1)}>
                        <Plus aria-hidden className="size-3.5" />
                      </IconButton>
                    </div>
                    <Money value={i.unitPrice * i.quantity} className="hidden w-20 text-right font-semibold text-ink sm:block" />
                    <IconButton label={`Remove ${i.productName}`} onClick={() => removeFromCart(i.productId)}>
                      <Trash2 aria-hidden className="size-4" />
                    </IconButton>
                  </li>
                ))}
              </ul>
            </Card>
          )
        })}
      </div>

      <aside className="lg:sticky lg:top-20 lg:self-start">
        <Card className="p-5">
          <h2 className="font-semibold text-ink">Summary</h2>
          <dl className="mt-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <dt className="text-ink-2">Items</dt>
              <dd className="tabular-nums">{items.reduce((s, i) => s + i.quantity, 0)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-2">Subtotal</dt>
              <dd><Money value={subtotal} /></dd>
            </div>
            <div className="flex justify-between text-ink-3">
              <dt>Delivery fee</dt>
              <dd>At checkout</dd>
            </div>
          </dl>
          {groups.length > 1 ? <p className="mt-4 rounded-xl bg-info-bg px-3 py-2 text-xs text-brand-ink">Items from {groups.length} vendors become {groups.length} separate orders, one drone flight each.</p> : null}
          <ButtonLink to="/user/checkout" size="lg" className="mt-5 w-full">
            Checkout
          </ButtonLink>
        </Card>
      </aside>
    </div>
  )
}
