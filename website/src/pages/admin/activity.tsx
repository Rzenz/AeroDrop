import { ScrollText, Search, ShieldCheck, UserPlus } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Skeleton } from '@/components/ui/loader'
import { Badge, Card, CardHeader, EmptyState, Input } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { deliveryStatusMeta, formatDateTime, shortId, timeAgo } from '@/lib/format'
import { useQuery } from '@/lib/store'
import type { DeliveryStatus } from '@/types'

export default function ActivityLogs() {
  const logs = useQuery(() => api.statusLogs(), [], 10_000)
  // reports_page.dart: the last 10 drone safety checks and the last 10 sign-ups.
  const checks = useQuery(() => api.safetyChecks(), [], 30_000)
  const users = useQuery(() => api.users(), [], 30_000)
  const recentUsers = [...(users.data ?? [])].sort((a, b) => b.created_at.localeCompare(a.created_at)).slice(0, 6)
  const [q, setQ] = useState('')
  const term = q.trim().toLowerCase()
  const shown = (logs.data ?? []).filter((l) => !term || `${l.status} ${l.message} ${l.delivery_id}`.toLowerCase().includes(term))

  return (
    <div className="flex flex-col gap-5">
      <div className="grid gap-5 lg:grid-cols-2">
        {checks.data ? (
          <Card>
            <CardHeader title="Drone safety checks" description="Latest pre-flight and in-flight checks." />
            {checks.data.length ? (
              <ul className="divide-y divide-line px-5 pb-3">
                {checks.data.map((c, i) => {
                  const passed = c.passed === true
                  return (
                    <li key={String(c.id ?? i)} className="flex items-start gap-3 py-3">
                      <Badge tone={passed ? 'success' : 'warning'}>{passed ? 'PASS' : 'WARN'}</Badge>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium text-ink">{String(c.check_type ?? 'Safety Check')}</p>
                        <p className="text-sm text-ink-2">{String(c.notes ?? 'Routine check passed')}</p>
                      </div>
                      {c.checked_at ? <time className="text-xs whitespace-nowrap text-ink-3">{timeAgo(String(c.checked_at))}</time> : null}
                    </li>
                  )
                })}
              </ul>
            ) : (
              <EmptyState icon={<ShieldCheck aria-hidden className="size-5" />} title="No Telemetry Logs" body="Safety checks and telemetry diagnostic logs are clear." />
            )}
          </Card>
        ) : null}
        <Card className={checks.data ? '' : 'lg:col-span-2'}>
          <CardHeader title="User activity" description="Most recent registrations." />
          {users.loading ? (
            <div className="space-y-2 p-4">{[0, 1, 2].map((i) => <Skeleton key={i} className="h-10" />)}</div>
          ) : recentUsers.length ? (
            <ul className="divide-y divide-line px-5 pb-3">
              {recentUsers.map((u) => (
                <li key={u.id} className="flex items-center gap-3 py-3">
                  <div className="min-w-0 flex-1">
                    <Link to={`/admin/users/${u.id}`} className="block truncate text-sm font-medium text-ink hover:underline">{u.full_name || 'User'}</Link>
                    <p className="text-xs text-ink-3">Status: {u.account_status ?? 'active'} · {timeAgo(u.created_at)}</p>
                  </div>
                  <Badge>{u.role.toUpperCase()}</Badge>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState icon={<UserPlus aria-hidden className="size-5" />} title="No User Activity" body="User registrations and activity will appear here." />
          )}
        </Card>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-ink-2">Raw audit trail of every delivery state change.</p>
        <div className="relative w-full sm:w-72">
          <Search aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-ink-3" />
          <Input type="search" aria-label="Search logs" placeholder="Status, message or ID" value={q} onChange={(e) => setQ(e.target.value)} className="pl-10" />
        </div>
      </div>
      <Card className="overflow-hidden">
        {logs.loading ? (
          <div className="space-y-2 p-4">{[0, 1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-10" />)}</div>
        ) : shown.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[680px] text-sm">
              <thead className="text-left text-xs text-ink-3">
                <tr className="shadow-[inset_0_-1px_0_var(--line)]">
                  {['Time', 'Delivery', 'Status', 'Message'].map((h) => <th key={h} scope="col" className="px-4 py-3 font-medium">{h}</th>)}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {shown.map((l) => {
                  const meta = deliveryStatusMeta[l.status as DeliveryStatus]
                  return (
                    <tr key={l.id}>
                      <td className="px-4 py-2.5 whitespace-nowrap text-ink-2 tabular-nums">{formatDateTime(l.created_at)}</td>
                      <td className="px-4 py-2.5"><Link to={`/admin/deliveries/details?id=${l.delivery_id}`} className="font-mono text-xs font-semibold text-brand-ink hover:underline">{shortId(l.delivery_id)}</Link></td>
                      <td className="px-4 py-2.5"><Badge tone={meta?.tone ?? 'neutral'}>{meta?.label ?? l.status}</Badge></td>
                      <td className="px-4 py-2.5 text-ink-2">{l.message ?? '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState icon={<ScrollText aria-hidden className="size-5" />} title="No log entries" body={term ? 'Try another search.' : 'Entries appear as deliveries change state.'} />
        )}
      </Card>

    </div>
  )
}
