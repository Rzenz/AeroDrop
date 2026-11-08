import { CheckCircle2, LifeBuoy, MessagesSquare, RotateCcw } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Button, ButtonLink } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Badge, Card, EmptyState, Field, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { reportCategoryLabel } from '@/lib/constants'
import { formatDateTime, shortId, timeAgo } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'

export default function AdminSupport() {
  const reports = useQuery(() => api.reports(), [], 20_000)
  const [tab, setTab] = useState<'open' | 'resolved'>('open')
  const [selected, setSelected] = useState<string | null>(null)
  const [notes, setNotes] = useState('')
  const [busy, setBusy] = useState(false)

  const all = reports.data ?? []
  const shown = all.filter((r) => r.status === tab)
  const current = all.find((r) => r.id === selected) ?? shown[0]
  useEffect(() => setNotes(current?.admin_notes ?? ''), [current?.id, current?.admin_notes])

  async function update(patch: { status?: 'open' | 'resolved'; admin_notes?: string }, ok: string) {
    if (!current) return
    setBusy(true)
    try {
      await api.updateReport(current.id, patch)
      invalidate()
      toast(ok)
    } catch (e) {
      toast(errorMessage(e), 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <AnimatedTabs label="Report status" value={tab} onChange={(t) => (setTab(t), setSelected(null))} tabs={[{ value: 'open', label: 'Open', count: all.filter((r) => r.status === 'open').length }, { value: 'resolved', label: 'Resolved' }]} />
      {reports.loading ? (
        <Skeleton className="h-80 rounded-2xl" />
      ) : !shown.length ? (
        <Card><EmptyState icon={<LifeBuoy aria-hidden className="size-5" />} title={tab === 'open' ? 'No open reports' : 'Nothing resolved yet'} body={tab === 'open' ? 'New reports from customers land here and notify every admin.' : undefined} /></Card>
      ) : (
        <div className="grid gap-5 lg:grid-cols-[360px_minmax(0,1fr)]">
          <Card className="p-2 lg:self-start">
            <ul>
              {shown.map((r) => (
                <li key={r.id}>
                  <button type="button" onClick={() => setSelected(r.id)} aria-current={current?.id === r.id || undefined} className={cn('w-full rounded-xl px-3 py-3 text-left transition-colors duration-150', current?.id === r.id ? 'bg-info-bg' : 'hover:bg-sunken')}>
                    <span className="flex items-center justify-between gap-2">
                      <span className="truncate font-medium text-ink">{r.subject}</span>
                      <span className="flex shrink-0 items-center gap-2 text-xs text-ink-3">
                        {r.unread_count ? (
                          <span className="grid h-5 min-w-5 place-items-center rounded-full bg-brand px-1.5 text-[11px] font-bold text-on-brand tabular-nums">
                            {r.unread_count}
                            <span className="sr-only"> unread replies</span>
                          </span>
                        ) : null}
                        {timeAgo(r.last_message_at && r.last_message_at > r.created_at ? r.last_message_at : r.created_at)}
                      </span>
                    </span>
                    <span className="mt-0.5 block truncate text-xs text-ink-3">{r.reporter_name ?? 'Customer'} · {reportCategoryLabel(r.category)}</span>
                  </button>
                </li>
              ))}
            </ul>
          </Card>
          {current ? (
            <Card className="p-6">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h2 className="font-display text-xl font-bold text-ink">{current.subject}</h2>
                  <p className="mt-1 text-sm text-ink-3">{current.reporter_name ?? 'Customer'} · {formatDateTime(current.created_at)}</p>
                </div>
                <div className="flex gap-2">
                  <Badge tone="info">{reportCategoryLabel(current.category)}</Badge>
                  <Badge tone={current.status === 'resolved' ? 'success' : 'warning'}>{current.status === 'resolved' ? 'Resolved' : 'Open'}</Badge>
                </div>
              </div>
              <p className="mt-5 rounded-xl bg-sunken p-4 text-sm whitespace-pre-line text-ink">{current.message}</p>
              {current.order_id ? <Link to={`/admin/deliveries/details?id=${current.order_id}`} className="mt-3 inline-block text-sm font-semibold text-brand-ink hover:underline">Open order {shortId(current.order_id)} and its chat</Link> : null}
              <Field label="Internal notes" hint="Saving notes alone does not notify the customer." className="mt-6">{(p) => <Textarea {...p} value={notes} onChange={(e) => setNotes(e.target.value)} className="min-h-28" />}</Field>
              <div className="mt-4 flex flex-wrap gap-2">
                <ButtonLink to={`/admin/support/${current.id}`} icon={<MessagesSquare aria-hidden className="size-4" />}>
                  Open Thread{current.unread_count ? ` (${current.unread_count} new)` : ''}
                </ButtonLink>
                <Button variant="secondary" loading={busy} disabled={notes === (current.admin_notes ?? '')} onClick={() => update({ admin_notes: notes }, 'Notes saved.')}>Save notes</Button>
                {current.status === 'open' ? (
                  <Button loading={busy} icon={<CheckCircle2 aria-hidden className="size-4" />} onClick={() => update({ status: 'resolved', admin_notes: notes }, 'Report resolved. The customer was notified.')}>Resolve</Button>
                ) : (
                  <Button variant="outline" loading={busy} icon={<RotateCcw aria-hidden className="size-4" />} onClick={() => update({ status: 'open' }, 'Report reopened. The customer was notified.')}>Reopen</Button>
                )}
              </div>
            </Card>
          ) : null}
        </div>
      )}
    </div>
  )
}
