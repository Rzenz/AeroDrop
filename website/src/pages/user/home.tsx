import { ArrowRight, MapPin, Navigation, ReceiptText, ShoppingBag } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth, useMe } from '@/auth/auth'
import TextShimmer from '@/components/forgeui/text-shimmer'
import { OrderRow, OrderStatusBadge, ProgressBar } from '@/components/orders'
import { ButtonLink } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Card, CardHeader, EmptyState, ErrorNote, Select } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { VendorCard } from '@/components/vendor-card'
import { WeatherCard } from '@/components/weather-card'
import { api } from '@/data/api'
import { effectiveStatus, formatPeso } from '@/lib/format'
import { isHub, legProgress, phaseOf } from '@/lib/flight'
import { errorMessage, useQuery } from '@/lib/store'

export default function UserHome() {
  const me = useMe()
  const { refresh } = useAuth()
  const locations = useQuery(() => api.locations())
  const vendors = useQuery(() => api.vendors())
  const orders = useQuery(() => api.orders(), [], 5000)

  const dropoffs = (locations.data ?? []).filter((l) => !isHub(l))
  const live = (orders.data ?? []).find((o) => !['delivered', 'cancelled', 'rejected'].includes(effectiveStatus(o)))
  const featured = [...(vendors.data ?? [])].sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0)).slice(0, 3)
  const hour = new Date().getHours()

  async function setDropoff(id: string) {
    try {
      await api.updateProfile(me.id, { campus_location_id: id || null })
      await refresh()
      toast('Drop-off saved.')
    } catch (e) {
      toast(errorMessage(e) || 'Could not save your drop-off. Please try again.', 'error')
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <section className="grid gap-4 lg:grid-cols-[1.4fr_1fr]">
        <Card className="flex flex-col justify-between gap-6 p-6">
          <div>
            <p className="text-sm text-ink-3">{hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'},</p>
            <h2 className="mt-1 font-display text-3xl font-extrabold text-ink">{me.full_name.split(' ')[0]}</h2>
            <p className="mt-2 text-ink-2">What should the drone bring you today?</p>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
            <label className="flex-1">
              <span className="mb-1.5 flex items-center gap-1.5 text-sm font-medium text-ink">
                <MapPin aria-hidden className="size-4 text-brand" /> Deliver to
              </span>
              <Select value={me.campus_location_id ?? ''} onChange={(e) => setDropoff(e.target.value)} aria-label="Default drop-off building">
                <option value="">Choose your drop-off</option>
                {dropoffs.map((l) => (
                  <option key={l.id} value={l.id}>
                    {l.name}
                  </option>
                ))}
              </Select>
            </label>
            <ButtonLink to="/user/shop" icon={<ShoppingBag aria-hidden className="size-4" />}>
              Browse vendors
            </ButtonLink>
          </div>
        </Card>
        <WeatherCard />
      </section>

      {live ? (
        <Card className="overflow-hidden">
          <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center">
            <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-gradient-to-b from-[#4FB1F6] to-[#3A6FD4] text-white">
              <Navigation aria-hidden className="size-5" />
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <p className="font-semibold text-ink">{live.vendor_name}</p>
                <OrderStatusBadge order={live} />
              </div>
              {live.delivery?.status === 'in_transit' || live.delivery?.status === 'assigning' ? (
                <>
                  <TextShimmer className="mt-1 text-sm font-medium">
                    {phaseOf(live.delivery) === 'to_vendor' ? 'The drone is flying to the vendor' : phaseOf(live.delivery) === 'waiting' ? 'Waiting for the next free drone' : 'The drone is on its way to you'}
                  </TextShimmer>
                  <ProgressBar value={legProgress(live.delivery)} label="Flight progress" className="mt-2 max-w-md" />
                </>
              ) : (
                <p className="mt-1 text-sm text-ink-2">
                  {live.items.length} item(s) · {formatPeso(live.total_amount)}
                </p>
              )}
            </div>
            <div className="flex gap-2">
              {live.delivery?.status === 'in_transit' || live.delivery?.status === 'assigning' ? (
                <ButtonLink to={`/user/track?id=${live.delivery.id}`} size="sm">
                  Track live
                </ButtonLink>
              ) : null}
              <ButtonLink to={`/user/orders/${live.id}`} variant="secondary" size="sm">
                Details
              </ButtonLink>
            </div>
          </div>
        </Card>
      ) : null}

      <section>
        <div className="mb-3 flex items-end justify-between">
          <h2 className="font-display text-lg font-bold text-ink">Featured</h2>
          <Link to="/user/shop" className="inline-flex items-center gap-1 text-sm font-semibold text-brand-ink hover:underline">
            See all <ArrowRight aria-hidden className="size-4" />
          </Link>
        </div>
        {vendors.error ? <ErrorNote message="Unable to load vendors." onRetry={vendors.reload} /> : null}
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {vendors.loading
            ? [0, 1, 2].map((i) => <Skeleton key={i} className="h-40 rounded-2xl" />)
            : featured.map((v) => <VendorCard key={v.id} vendor={v} location={locations.data?.find((l) => l.id === v.campus_location_id)} />)}
        </div>
        {!vendors.loading && !featured.length ? <EmptyState title="No vendors available" body="Campus vendors will appear here once they open." /> : null}
      </section>

      <Card>
        <CardHeader
          title="Recent Orders"
          action={
            <Link to="/user/orders" className="text-sm font-semibold text-brand-ink hover:underline">
              View all
            </Link>
          }
        />
        <div className="p-2">
          {orders.loading ? (
            <div className="space-y-2 p-3">
              {[0, 1, 2].map((i) => (
                <Skeleton key={i} className="h-14" />
              ))}
            </div>
          ) : orders.data?.length ? (
            <ul>
              {orders.data.slice(0, 4).map((o) => (
                <OrderRow key={o.id} order={o} to={`/user/orders/${o.id}`} perspective="user" />
              ))}
            </ul>
          ) : (
            <EmptyState icon={<ReceiptText aria-hidden className="size-5" />} title="No orders yet" body="Your recent orders will show up here." action={<ButtonLink to="/user/shop">Start an order</ButtonLink>} />
          )}
        </div>
      </Card>
    </div>
  )
}
