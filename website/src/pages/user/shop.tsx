import { Search, Store } from 'lucide-react'
import { useMemo, useState } from 'react'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { ProductCard } from '@/components/product-card'
import { Skeleton } from '@/components/ui/loader'
import { EmptyState, ErrorNote, Input } from '@/components/ui/primitives'
import { VendorCard } from '@/components/vendor-card'
import { api } from '@/data/api'
import { useQuery } from '@/lib/store'

export default function Shop() {
  const vendors = useQuery(() => api.vendors())
  const products = useQuery(() => api.products())
  const locations = useQuery(() => api.locations())
  const [q, setQ] = useState('')
  const [cat, setCat] = useState('All')

  const categories = useMemo(() => ['All', ...new Set((vendors.data ?? []).map((v) => v.business_category).filter(Boolean) as string[])], [vendors.data])
  const term = q.trim().toLowerCase()
  const shownVendors = (vendors.data ?? []).filter(
    (v) => (cat === 'All' || v.business_category === cat) && (!term || `${v.business_name} ${v.business_description}`.toLowerCase().includes(term)),
  )
  const vendorName = new Map((vendors.data ?? []).map((v) => [v.id, v.business_name ?? '']))
  const shownProducts = term ? (products.data ?? []).filter((p) => vendorName.has(p.vendor_id) && `${p.name} ${p.category}`.toLowerCase().includes(term)) : []

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div className="relative w-full lg:max-w-md">
          <Search aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-ink-3" />
          <Input type="search" aria-label="Search vendors and products" placeholder="Search vendors or products" value={q} onChange={(e) => setQ(e.target.value)} className="pl-10" />
        </div>
        <AnimatedTabs label="Vendor category" value={cat} onChange={setCat} tabs={categories.map((c) => ({ value: c, label: c }))} />
      </div>

      {vendors.error ? <ErrorNote message="Unable to load vendors." onRetry={vendors.reload} /> : null}

      {term && shownProducts.length ? (
        <section>
          <h2 className="mb-3 font-display text-lg font-bold text-ink">Products</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {shownProducts.slice(0, 8).map((p) => (
              <ProductCard key={p.id} product={p} vendorName={vendorName.get(p.vendor_id) ?? ''} />
            ))}
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Vendors{vendors.data ? <span className="ml-2 text-sm font-medium text-ink-3 tabular-nums">{shownVendors.length}</span> : null}</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {vendors.loading
            ? Array.from({ length: 6 }, (_, i) => <Skeleton key={i} className="h-40 rounded-2xl" />)
            : shownVendors.map((v) => <VendorCard key={v.id} vendor={v} location={locations.data?.find((l) => l.id === v.campus_location_id)} />)}
        </div>
        {!vendors.loading && !shownVendors.length ? (
          <EmptyState
            icon={<Store aria-hidden className="size-5" />}
            title={term ? 'No matches' : 'No vendors available'}
            body={term ? `Nothing matches “${q}”. Try another word.` : 'Check back soon.'}
            action={
              term || cat !== 'All' ? (
                <button type="button" onClick={() => (setQ(''), setCat('All'))} className="font-semibold text-brand-ink hover:underline">
                  Clear filters
                </button>
              ) : undefined
            }
          />
        ) : null}
      </section>
    </div>
  )
}
