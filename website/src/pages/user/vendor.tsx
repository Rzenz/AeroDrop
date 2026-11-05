import { ArrowLeft, MapPin, Package, Star } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { ProductCard } from '@/components/product-card'
import { PageLoader, Skeleton } from '@/components/ui/loader'
import { Avatar, Badge, Card, EmptyState, Rating } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { timeAgo } from '@/lib/format'
import { useQuery } from '@/lib/store'

export default function VendorPage() {
  const { id = '' } = useParams()
  const vendors = useQuery(() => api.vendors())
  const products = useQuery(() => api.products({ vendorId: id }), [id])
  const reviews = useQuery(() => api.vendorReviews(id), [id])
  const locations = useQuery(() => api.locations())
  const [cat, setCat] = useState('All')

  const vendor = vendors.data?.find((v) => v.id === id)
  const cats = useMemo(() => ['All', ...new Set((products.data ?? []).map((p) => p.category ?? 'Other'))], [products.data])
  const shown = (products.data ?? []).filter((p) => cat === 'All' || (p.category ?? 'Other') === cat)

  if (vendors.loading) return <PageLoader />
  if (!vendor) return <EmptyState title="Store not found" body="This vendor is not open on AeroDrop right now." action={<Link to="/user/shop" className="font-semibold text-brand-ink hover:underline">Back to Shop</Link>} />
  const loc = locations.data?.find((l) => l.id === vendor.campus_location_id)

  return (
    <div className="flex flex-col gap-6">
      <Link to="/user/shop" className="inline-flex w-fit items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
        <ArrowLeft aria-hidden className="size-4" /> Shop
      </Link>
      <Card className="flex flex-col gap-5 p-6 sm:flex-row sm:items-center">
        <Avatar name={vendor.business_name} src={vendor.business_logo_url} size={72} className="rounded-2xl" />
        <div className="min-w-0 flex-1">
          <h2 className="font-display text-2xl font-extrabold text-ink">{vendor.business_name}</h2>
          {vendor.business_description ? <p className="mt-1 text-ink-2">{vendor.business_description}</p> : null}
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <Rating value={vendor.rating} count={vendor.review_count} />
            {vendor.business_category ? <Badge tone="info">{vendor.business_category}</Badge> : null}
            {loc ? (
              <span className="inline-flex items-center gap-1 text-sm text-ink-3">
                <MapPin aria-hidden className="size-4" /> Picks up at {loc.name}
              </span>
            ) : null}
          </div>
        </div>
      </Card>

      <div className="grid gap-6 xl:grid-cols-[1fr_320px]">
        <section>
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <h2 className="font-display text-lg font-bold text-ink">Menu</h2>
            {cats.length > 2 ? <AnimatedTabs label="Product category" value={cat} onChange={setCat} tabs={cats.map((c) => ({ value: c, label: c }))} /> : null}
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {products.loading ? Array.from({ length: 6 }, (_, i) => <Skeleton key={i} className="h-64 rounded-2xl" />) : shown.map((p) => <ProductCard key={p.id} product={p} vendorName={vendor.business_name ?? ''} />)}
          </div>
          {!products.loading && !shown.length ? <EmptyState icon={<Package aria-hidden className="size-5" />} title="No items listed" body="This store has not added products yet." /> : null}
        </section>

        <aside>
          <Card className="p-5">
            <h2 className="flex items-center gap-2 font-semibold text-ink">
              <Star aria-hidden className="size-4 text-[#F0A03C]" /> Reviews
            </h2>
            {reviews.data?.length ? (
              <ul className="mt-4 space-y-4">
                {reviews.data.slice(0, 6).map((r) => (
                  <li key={r.id} className="text-sm">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-ink">{r.reviewer_name ?? 'Customer'}</span>
                      <span className="text-xs text-ink-3">{timeAgo(r.created_at)}</span>
                    </div>
                    <Rating value={r.rating} className="mt-0.5" />
                    {r.comment ? <p className="mt-1 text-ink-2">{r.comment}</p> : null}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-3 text-sm text-ink-3">No reviews yet. Reviews come from verified deliveries.</p>
            )}
          </Card>
        </aside>
      </div>
    </div>
  )
}
