import { ArrowLeft, Ban, Check, RotateCcw, Store, Trash2 } from 'lucide-react'
import { Link, useParams } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { OrderRow, StatTile } from '@/components/orders'
import { Button } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/ui/dialog'
import { PageLoader } from '@/components/ui/loader'
import { Avatar, Badge, Card, CardHeader, EmptyState } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { effectiveStatus, formatDate, formatPeso } from '@/lib/format'
import { useQuery } from '@/lib/store'
import { accountTone, adminAction } from './users'

export default function AdminUserDetail() {
  const { id = '' } = useParams()
  const me = useMe()
  const user = useQuery(() => api.profile(id), [id])
  const orders = useQuery(() => api.orders())
  const locations = useQuery(() => api.locations())

  if (user.loading) return <PageLoader />
  const u = user.data
  if (!u) return <EmptyState title="Account not found." action={<Link to="/admin/users" className="font-semibold text-brand-ink hover:underline">Back to users</Link>} />

  const isSelf = u.id === me.id
  const theirs = (orders.data ?? []).filter((o) => o.user_id === u.id || o.vendor_id === u.id)
  const delivered = theirs.filter((o) => effectiveStatus(o) === 'delivered')
  const [label, tone] = accountTone(u)
  const loc = locations.data?.find((l) => l.id === u.campus_location_id)

  return (
    <div className="flex flex-col gap-6">
      <Link to="/admin/users" className="inline-flex w-fit items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
        <ArrowLeft aria-hidden className="size-4" /> Users & Vendors
      </Link>
      <Card className="flex flex-col gap-5 p-6 md:flex-row md:items-center">
        <Avatar name={u.full_name} src={u.avatar_url ?? u.business_logo_url} size={72} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="font-display text-2xl font-extrabold text-ink">{u.full_name}</h2>
            <Badge tone={tone} dot>{label}</Badge>
            <Badge tone="info">{u.role === 'admin' ? 'Admin' : u.vendor_status ? 'Vendor' : 'Customer'}</Badge>
          </div>
          <p className="mt-1 text-sm text-ink-3">{u.email} · {u.phone_number ?? 'No phone'} · Joined {formatDate(u.created_at)}</p>
          {u.business_name ? (
            <p className="mt-2 flex items-center gap-1.5 text-sm text-ink-2"><Store aria-hidden className="size-4" /> {u.business_name} · {u.business_category} {loc ? `· ${loc.name}` : ''}</p>
          ) : null}
        </div>
        {!isSelf && u.role !== 'admin' ? (
          <div className="flex flex-wrap gap-2">
            {u.vendor_status === 'pending' ? (
              <>
                <Button icon={<Check aria-hidden className="size-4" />} onClick={() => adminAction(() => api.setVendorStatus(u.id, 'active'), 'Vendor approved.')}>Approve store</Button>
                <ConfirmDialog trigger={<Button variant="ghost">Reject</Button>} title="Reject this application?" body="The applicant is notified." confirmLabel="Reject" onConfirm={() => adminAction(() => api.setVendorStatus(u.id, 'rejected'), 'Application rejected.')} />
              </>
            ) : null}
            {u.vendor_status === 'active' ? <ConfirmDialog trigger={<Button variant="outline">Suspend store</Button>} title="Suspend this store?" body="Customers stop seeing it. The owner keeps their account." confirmLabel="Suspend store" onConfirm={() => adminAction(() => api.setVendorStatus(u.id, 'suspended'), 'Store suspended.')} /> : null}
            {u.vendor_status === 'suspended' || u.vendor_status === 'rejected' ? <Button variant="secondary" icon={<RotateCcw aria-hidden className="size-4" />} onClick={() => adminAction(() => api.setVendorStatus(u.id, 'active'), 'Store reactivated.')}>Reactivate store</Button> : null}
            {u.account_status === 'active' ? (
              <ConfirmDialog trigger={<Button variant="outline" icon={<Ban aria-hidden className="size-4" />}>Suspend account</Button>} title={`Suspend ${u.full_name}?`} body="They are signed out within seconds and can’t sign in until reactivated." confirmLabel="Suspend account" onConfirm={() => adminAction(() => api.setAccountStatus(u.id, 'suspended'), 'Account suspended.')} />
            ) : u.account_status === 'suspended' ? (
              <Button variant="secondary" icon={<RotateCcw aria-hidden className="size-4" />} onClick={() => adminAction(() => api.setAccountStatus(u.id, 'active'), 'Account reactivated.')}>Reactivate account</Button>
            ) : null}
            {u.account_status !== 'deleted' ? <ConfirmDialog trigger={<Button variant="danger" icon={<Trash2 aria-hidden className="size-4" />}>Delete</Button>} title={`Delete ${u.full_name}?`} body="The account is soft-deleted. Order history stays for reporting. This can’t be undone from the website." confirmLabel="Delete account" onConfirm={() => adminAction(() => api.deleteUser(u.id), 'Account deleted.')} /> : null}
          </div>
        ) : null}
      </Card>

      <div className="grid gap-4 sm:grid-cols-3">
        <StatTile label="Orders" value={theirs.length} />
        <StatTile label="Delivered" value={delivered.length} />
        <StatTile label={u.vendor_status ? 'Sales' : 'Spent'} value={formatPeso(delivered.reduce((s, o) => s + (u.vendor_status ? o.subtotal : o.total_amount), 0))} />
      </div>

      <Card>
        <CardHeader title="Orders" />
        <div className="p-2">
          {theirs.length ? <ul>{theirs.slice(0, 12).map((o) => <OrderRow key={o.id} order={o} to={`/admin/deliveries/details?id=${o.delivery?.id ?? o.id}`} perspective={u.vendor_status ? 'admin' : 'user'} />)}</ul> : <EmptyState title="No orders yet" />}
        </div>
      </Card>
    </div>
  )
}
