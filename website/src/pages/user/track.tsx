import { Navigation } from 'lucide-react'
import { useSearchParams } from 'react-router-dom'
import { FlightPanel } from '@/components/flight-panel'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { ButtonLink } from '@/components/ui/button'
import { PageLoader } from '@/components/ui/loader'
import { Card, EmptyState } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { useQuery } from '@/lib/store'

export default function Track() {
  const [params, setParams] = useSearchParams()
  const orders = useQuery(() => api.orders(), [], 4000)
  if (orders.loading) return <PageLoader />

  const tracked = (orders.data ?? []).filter((o) => o.delivery && ['in_transit', 'assigning', 'pending'].includes(o.delivery.status))
  if (!tracked.length) {
    const recent = (orders.data ?? []).find((o) => o.delivery?.status === 'delivered')
    return (
      <Card>
        <EmptyState
          icon={<Navigation aria-hidden className="size-5" />}
          title="No drone in the air for you"
          body={recent ? 'Your last delivery has landed. Live tracking starts when the vendor marks your next order ready.' : 'Live tracking starts when the vendor marks your order ready for pickup.'}
          action={recent ? <ButtonLink to={`/user/orders/${recent.id}`} variant="secondary">View last delivery</ButtonLink> : <ButtonLink to="/user/shop">Order something</ButtonLink>}
        />
      </Card>
    )
  }

  const selected = tracked.find((o) => o.delivery!.id === params.get('id')) ?? tracked[0]!
  return (
    <div className="flex flex-col gap-4">
      {tracked.length > 1 ? (
        <AnimatedTabs label="Delivery" value={selected.delivery!.id} onChange={(id) => setParams({ id })} tabs={tracked.map((o) => ({ value: o.delivery!.id, label: o.vendor_name ?? 'Order' }))} />
      ) : null}
      <FlightPanel order={selected} mapClassName="h-[min(60dvh,520px)]" />
      <ButtonLink to={`/user/orders/${selected.id}`} variant="secondary" className="self-start">
        Order details and chat
      </ButtonLink>
    </div>
  )
}
