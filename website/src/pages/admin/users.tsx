import { Check, Search, Users, X } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Button } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/ui/dialog'
import { Skeleton } from '@/components/ui/loader'
import { Avatar, Badge, Card, CardHeader, EmptyState, Input } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { formatDate, type Tone } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import type { Profile } from '@/types'

type Tab = 'customers' | 'vendors' | 'applications' | 'restricted'

export const accountTone = (u: Profile): [string, Tone] =>
  u.account_status === 'deleted' ? ['Deleted', 'neutral'] : u.account_status === 'suspended' ? ['Suspended', 'danger'] : u.vendor_status === 'pending' ? ['Pending review', 'warning'] : u.vendor_status === 'rejected' ? ['Rejected', 'neutral'] : u.vendor_status === 'suspended' ? ['Store suspended', 'danger'] : ['Active', 'success']

export async function adminAction(fn: () => Promise<unknown>, ok: string) {
  try {
    await fn()
    invalidate()
    toast(ok)
  } catch (e) {
    toast(errorMessage(e), 'error')
  }
}

export default function AdminUsers() {
  const users = useQuery(() => api.users())
  const [tab, setTab] = useState<Tab>('customers')
  const [q, setQ] = useState('')
  const all = (users.data ?? []).filter((u) => u.role !== 'admin')
  const pending = all.filter((u) => u.vendor_status === 'pending')
  const bucket: Record<Tab, Profile[]> = {
    customers: all.filter((u) => u.role === 'user' && !u.vendor_status && u.account_status === 'active'),
    vendors: all.filter((u) => u.vendor_status && u.vendor_status !== 'pending' && u.account_status === 'active'),
    applications: pending,
    restricted: all.filter((u) => u.account_status !== 'active'),
  }
  const term = q.trim().toLowerCase()
  const shown = bucket[tab].filter((u) => !term || `${u.full_name} ${u.email} ${u.business_name ?? ''}`.toLowerCase().includes(term))

  return (
    <div className="flex flex-col gap-5">
      {pending.length ? (
        <Card>
          <CardHeader title="Vendor applications" description={`${pending.length} waiting for review`} />
          <ul className="grid gap-3 p-5 md:grid-cols-2">
            {pending.map((u) => (
              <li key={u.id} className="flex flex-col gap-3 rounded-xl bg-sunken p-4">
                <div className="flex items-center gap-3">
                  <Avatar name={u.business_name} src={u.business_logo_url} size={40} className="rounded-xl" />
                  <div className="min-w-0 flex-1">
                    <Link to={`/admin/users/${u.id}`} className="font-semibold text-ink hover:underline">{u.business_name}</Link>
                    <p className="truncate text-xs text-ink-3">{u.business_category} · {u.full_name} · {u.email}</p>
                  </div>
                </div>
                {u.business_description ? <p className="line-clamp-2 text-sm text-ink-2">{u.business_description}</p> : null}
                <div className="flex gap-2">
                  <Button size="sm" icon={<Check aria-hidden className="size-4" />} onClick={() => adminAction(() => api.setVendorStatus(u.id, 'active'), `${u.business_name} approved.`)}>Approve</Button>
                  <ConfirmDialog trigger={<Button size="sm" variant="ghost" icon={<X aria-hidden className="size-4" />}>Reject</Button>} title={`Reject ${u.business_name}?`} body="The applicant is notified. They keep a customer account." confirmLabel="Reject application" onConfirm={() => adminAction(() => api.setVendorStatus(u.id, 'rejected'), `Application for "${u.business_name}" rejected.`)} />
                </div>
              </li>
            ))}
          </ul>
        </Card>
      ) : null}

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <AnimatedTabs
          label="Account type"
          value={tab}
          onChange={setTab}
          tabs={[
            { value: 'customers', label: 'Customers', count: bucket.customers.length },
            { value: 'vendors', label: 'Vendors', count: bucket.vendors.length },
            { value: 'applications', label: 'Applications', count: pending.length },
            { value: 'restricted', label: 'Suspended & deleted', count: bucket.restricted.length },
          ]}
        />
        <div className="relative lg:w-72">
          <Search aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-ink-3" />
          <Input type="search" aria-label="Search accounts" placeholder="Name, email or store" value={q} onChange={(e) => setQ(e.target.value)} className="pl-10" />
        </div>
      </div>

      <Card className="overflow-hidden">
        {users.loading ? (
          <div className="space-y-2 p-4">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-14" />)}</div>
        ) : shown.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-sm">
              <thead className="text-left text-xs text-ink-3">
                <tr className="shadow-[inset_0_-1px_0_var(--line)]">
                  {['Account', tab === 'vendors' || tab === 'applications' ? 'Store' : 'Phone', 'Joined', 'Status'].map((h) => <th key={h} scope="col" className="px-4 py-3 font-medium">{h}</th>)}
                  <th scope="col" className="px-4 py-3"><span className="sr-only">Actions</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {shown.map((u) => {
                  const [label, tone] = accountTone(u)
                  return (
                    <tr key={u.id} className="hover:bg-sunken/50">
                      <td className="px-4 py-3">
                        <Link to={`/admin/users/${u.id}`} className="flex items-center gap-3">
                          <Avatar name={u.full_name} src={u.avatar_url} size={34} />
                          <span className="min-w-0">
                            <span className="block truncate font-medium text-ink hover:underline">{u.full_name}</span>
                            <span className="block truncate text-xs text-ink-3">{u.email}</span>
                          </span>
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-ink-2">{tab === 'vendors' || tab === 'applications' ? (u.business_name ?? '—') : (u.phone_number ?? '—')}</td>
                      <td className="px-4 py-3 text-ink-2 tabular-nums">{formatDate(u.created_at)}</td>
                      <td className="px-4 py-3"><Badge tone={tone} dot>{label}</Badge></td>
                      <td className="px-4 py-3 text-right">
                        <Link to={`/admin/users/${u.id}`} className="text-sm font-semibold text-brand-ink hover:underline">Manage</Link>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState icon={<Users aria-hidden className="size-5" />} title="No accounts here" body={term ? 'Try another search.' : undefined} />
        )}
      </Card>
    </div>
  )
}
