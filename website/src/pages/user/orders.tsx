import { ReceiptText } from 'lucide-react'
import { useState } from 'react'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { OrderRow } from '@/components/orders'
import { ButtonLink } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Card, EmptyState, ErrorNote } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { effectiveStatus } from '@/lib/format'
import { useQuery } from '@/lib/store'

type Tab = 'active' | 'delivered' | 'cancelled'

export default function UserOrders() {
  const orders = useQuery(() => api.orders(), [], 10_000)
  const [tab, setTab] = useState<Tab>('active')
  const all = orders.data ?? []
  const bucket = (t: Tab) =>
    all.filter((o) => {
      const s = effectiveStatus(o)
      return t === 'delivered' ? s === 'delivered' : t === 'cancelled' ? s === 'cancelled' || s === 'rejected' : !['delivered', 'cancelled', 'rejected'].includes(s)
    })
  const shown = bucket(tab)

  return (
    <div className="flex flex-col gap-5">
      <AnimatedTabs
        label="Order status"
        value={tab}
        onChange={setTab}
        tabs={[
          { value: 'active', label: 'Active', count: bucket('active').length },
          { value: 'delivered', label: 'Delivered' },
          { value: 'cancelled', label: 'Cancelled' },
        ]}
      />
      {orders.error ? <ErrorNote message={orders.error} onRetry={orders.reload} /> : null}
      <Card className="p-2">
        {orders.loading ? (
          <div className="space-y-2 p-3">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-14" />
            ))}
          </div>
        ) : shown.length ? (
          <ul>
            {shown.map((o) => (
              <OrderRow key={o.id} order={o} to={`/user/orders/${o.id}`} perspective="user" />
            ))}
          </ul>
        ) : (
          <EmptyState
            icon={<ReceiptText aria-hidden className="size-5" />}
            title={tab === 'active' ? 'Nothing on the way' : tab === 'delivered' ? 'No deliveries yet' : 'No cancelled orders'}
            body={tab === 'active' ? 'Orders you place show up here until they land.' : undefined}
            action={tab === 'active' ? <ButtonLink to="/user/shop">Start an order</ButtonLink> : undefined}
          />
        )}
      </Card>
    </div>
  )
}
