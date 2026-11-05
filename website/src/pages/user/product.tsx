import { ArrowLeft, Minus, Plus, Scale, ShoppingCart } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { PageLoader } from '@/components/ui/loader'
import { Badge, Card, CardHeader, EmptyState, ProductArt, Rating } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { addToCart } from '@/lib/cart'
import { MAX_PAYLOAD_KG } from '@/lib/fees'
import { formatPeso, timeAgo } from '@/lib/format'
import { useQuery } from '@/lib/store'

export default function ProductPage() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const product = useQuery(() => api.product(id), [id])
  const vendors = useQuery(() => api.vendors())
  const reviews = useQuery(() => api.productReviews(id), [id])
  const [qty, setQty] = useState(1)

  if (product.loading) return <PageLoader />
  const p = product.data
  if (!p) return <EmptyState title="Product not found" action={<Link to="/user/shop" className="font-semibold text-brand-ink hover:underline">Back to Shop</Link>} />
  const vendor = vendors.data?.find((v) => v.id === p.vendor_id)
  const out = p.stock_quantity <= 0

  return (
    <div className="flex flex-col gap-6">
      <Link to={vendor ? `/user/vendors/${vendor.id}` : '/user/shop'} className="inline-flex w-fit items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
        <ArrowLeft aria-hidden className="size-4" /> {vendor?.business_name ?? 'Shop'}
      </Link>
      <Card className="grid overflow-hidden md:grid-cols-2">
        <div className="aspect-square bg-sunken md:aspect-auto">
          <ProductArt name={p.name} src={p.image_url} className="text-5xl" />
        </div>
        <div className="flex flex-col p-6 sm:p-8">
          <div className="flex flex-wrap items-center gap-2">
            {p.category ? <Badge tone="info">{p.category}</Badge> : null}
            {out ? <Badge tone="danger">Sold out</Badge> : p.stock_quantity <= 5 ? <Badge tone="warning">{p.stock_quantity} left</Badge> : <Badge tone="success">In stock</Badge>}
          </div>
          <h2 className="mt-3 font-display text-3xl font-extrabold text-ink">{p.name}</h2>
          <Rating value={p.rating} count={p.review_count} className="mt-2" />
          <p className="mt-4 font-display text-3xl font-bold text-ink tabular-nums">{formatPeso(p.price)}</p>
          {p.description ? <p className="mt-4 text-ink-2">{p.description}</p> : null}
          <p className="mt-4 inline-flex items-center gap-2 text-sm text-ink-3">
            <Scale aria-hidden className="size-4" /> {p.weight_grams} g each. One drone trip carries up to {MAX_PAYLOAD_KG} kg.
          </p>

          <div className="mt-auto flex flex-wrap items-center gap-3 pt-8">
            <div className="flex items-center rounded-xl bg-sunken p-1 shadow-[inset_0_0_0_1px_var(--line)]">
              <button type="button" aria-label="Decrease quantity" disabled={qty <= 1} onClick={() => setQty((q) => q - 1)} className="grid size-10 place-items-center rounded-lg text-ink transition-transform duration-150 hover:bg-surface active:scale-[0.96] disabled:opacity-40">
                <Minus aria-hidden className="size-4" />
              </button>
              <output aria-live="polite" className="w-10 text-center font-semibold text-ink tabular-nums">{qty}</output>
              <button type="button" aria-label="Increase quantity" disabled={qty >= p.stock_quantity} onClick={() => setQty((q) => q + 1)} className="grid size-10 place-items-center rounded-lg text-ink transition-transform duration-150 hover:bg-surface active:scale-[0.96] disabled:opacity-40">
                <Plus aria-hidden className="size-4" />
              </button>
            </div>
            <Button
              size="lg"
              disabled={out}
              className="flex-1"
              icon={<ShoppingCart aria-hidden className="size-5" />}
              onClick={() => {
                addToCart(p, vendor?.business_name ?? '', qty)
                toast(`${qty} × ${p.name} added to cart.`)
                navigate('/user/cart')
              }}
            >
              Add to cart · {formatPeso(p.price * qty)}
            </Button>
          </div>
        </div>
      </Card>
      <Card>
        <CardHeader title="Reviews" description={p.review_count ? `${p.review_count} review${p.review_count === 1 ? '' : 's'} from delivered orders.` : undefined} />
        {reviews.data?.length ? (
          <ul className="divide-y divide-line px-5 pb-3">
            {reviews.data.map((r) => (
              <li key={r.id} className="py-3 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <span className="font-semibold text-ink">{r.reviewer_name ?? 'Customer'}</span>
                  <span className="text-xs text-ink-3">{timeAgo(r.created_at)}</span>
                </div>
                <Rating value={r.rating} className="mt-0.5" />
                {r.comment?.trim() ? <p className="mt-1 text-ink-2">{r.comment.trim()}</p> : null}
              </li>
            ))}
          </ul>
        ) : (
          <p className="px-5 pb-5 text-sm text-ink-3">{reviews.loading ? 'Loading reviews…' : 'No reviews yet'}</p>
        )}
      </Card>
    </div>
  )
}
