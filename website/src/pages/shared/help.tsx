import { ChevronRight, Inbox, LifeBuoy, MessageSquarePlus } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/loader'
import { Badge, Card, CardHeader, ErrorNote, Field, Input, Select, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { REPORT_CATEGORIES, reportCategoryLabel } from '@/lib/constants'
import { timeAgo } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import type { SupportReport } from '@/types'

// The app's FAQ answers (help_support_page.dart) plus the web's own.
const faq = [
  ['What payloads can be delivered?', 'We support academic documents, books, laboratory samples, medical aid kits, and electronics up to 0.5 kg per drone trip. Orders up to 1.0 kg are flown in two trips.'],
  ['What happens in severe weather?', 'The fleet system automatically halts and queues dispatches if wind speeds exceed 15 knots or during heavy rain precipitation.'],
  ['How long does a delivery take?', 'Flight time comes from the real distance between the vendor and your building. Most campus flights take a few minutes once the drone picks up.'],
  ['Can I cancel?', 'Yes, until the vendor marks the order ready for drone pickup. Payment is refunded and stock restored.'],
  ['How is the delivery fee calculated?', '₱15 base, plus ₱40 per km and ₱10 per kg. Caution weather adds ₱5 and each extra trip adds ₱25.'],
]

/** ORD-XXXXXXXX, the app's order reference in prefilled subjects. */
const orderRef = (id: string) => `ORD-${id.replace(/-/g, '').slice(0, 8).toUpperCase()}`

const lastActivity = (r: SupportReport) => (r.last_message_at && r.last_message_at > r.created_at ? r.last_message_at : r.created_at)

export default function Help() {
  const me = useMe()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const orderId = params.get('orderId') ?? undefined
  const deliveryId = params.get('deliveryId') ?? undefined
  const reports = useQuery(() => api.reports(), [], 30_000)
  // Opened from an order or delivery, the user came to report something, so
  // the form starts open with that link filled in (as in the app).
  const [showForm, setShowForm] = useState(Boolean(orderId || deliveryId))

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
      <div className="flex flex-col gap-6">
        <Card>
          <CardHeader
            title="My Reports"
            description="Each report is a conversation with the AeroDrop team."
            action={
              showForm ? null : (
                <Button size="sm" icon={<MessageSquarePlus aria-hidden className="size-4" />} onClick={() => setShowForm(true)}>
                  New Report
                </Button>
              )
            }
          />
          {showForm ? (
            <ReportForm
              orderId={orderId}
              deliveryId={deliveryId}
              onCancel={() => setShowForm(false)}
              onSubmitted={(id) => {
                setShowForm(false)
                invalidate()
                navigate(`/${me.role}/help/${id}`)
              }}
            />
          ) : null}
          <div className="p-2">
            {reports.error && !reports.data ? (
              <div className="p-3">
                <ErrorNote message="Could not load your reports." onRetry={reports.reload} />
              </div>
            ) : reports.loading ? (
              <div className="space-y-2 p-3">{[0, 1].map((i) => <Skeleton key={i} className="h-16" />)}</div>
            ) : reports.data?.length ? (
              <ul>
                {reports.data.map((r) => (
                  <li key={r.id}>
                    <Link to={`/${me.role}/help/${r.id}`} className="flex items-center gap-3 rounded-xl px-3 py-3 transition-colors duration-150 hover:bg-sunken">
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-medium text-ink">{r.subject || 'Support report'}</span>
                        <span className="mt-0.5 block truncate text-xs text-ink-3">
                          {reportCategoryLabel(r.category)} · {timeAgo(lastActivity(r))}
                        </span>
                      </span>
                      {r.unread_count ? (
                        <span className="grid h-5 min-w-5 place-items-center rounded-full bg-brand px-1.5 text-[11px] font-bold text-on-brand tabular-nums">
                          {r.unread_count}
                          <span className="sr-only"> unread</span>
                        </span>
                      ) : null}
                      <Badge tone={r.status === 'resolved' ? 'success' : 'warning'}>{r.status === 'resolved' ? 'Resolved' : 'Open'}</Badge>
                      <ChevronRight aria-hidden className="size-4 shrink-0 text-ink-3" />
                    </Link>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="flex items-center justify-center gap-2 px-3 py-8 text-center text-sm text-ink-3">
                <Inbox aria-hidden className="size-4" /> No reports yet. Start one and our team will reply here.
              </p>
            )}
          </div>
        </Card>
      </div>
      <Card className="self-start">
        <CardHeader title="Frequently Asked Questions" />
        <div className="p-3">
          {faq.map(([q, a]) => (
            <details key={q} className="group rounded-xl px-3 py-3 open:bg-sunken">
              <summary className="cursor-pointer list-none font-medium text-ink marker:hidden">{q}</summary>
              <p className="mt-2 text-sm text-ink-2">{a}</p>
            </details>
          ))}
        </div>
      </Card>
    </div>
  )
}

function ReportForm({ orderId, deliveryId, onCancel, onSubmitted }: { orderId?: string; deliveryId?: string; onCancel: () => void; onSubmitted: (reportId: string) => void }) {
  // _SupportReportFormState.initState: a delivery or order prefills the category and subject.
  const [form, setForm] = useState(() =>
    deliveryId
      ? { category: 'delivery_issue', subject: orderId ? `Delivery Issue (${orderRef(orderId)})` : 'Delivery Issue', message: '' }
      : orderId
        ? { category: 'order_issue', subject: `Order Support (${orderRef(orderId)})`, message: '' }
        : { category: 'general', subject: '', message: '' },
  )
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (form.subject.trim().length < 4) return setError('Give the report a short subject.')
    if (form.message.trim().length < 10) return setError('Describe what happened in a sentence or two.')
    setBusy(true)
    try {
      const id = await api.submitReport({ ...form, orderId, deliveryId })
      toast('Support ticket submitted successfully! Our campus fleet team will review it.')
      onSubmitted(id)
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} noValidate className="mx-5 mt-4 mb-2 grid gap-4 rounded-2xl bg-sunken p-4 sm:grid-cols-2">
      <div className="flex items-center justify-between gap-3 sm:col-span-2">
        <p className="font-semibold text-ink">Submit a Support Request</p>
        <button type="button" onClick={onCancel} className="h-9 rounded-lg px-3 text-sm font-semibold text-ink-2 hover:bg-surface hover:text-ink">
          Cancel
        </button>
      </div>
      {orderId ? (
        <p className="text-xs text-ink-3 sm:col-span-2">
          Linked Order: {orderRef(orderId)}
          {deliveryId ? ' • Delivery Attached' : ''}
        </p>
      ) : null}
      <Field label="Subject">{(p) => <Input {...p} value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} maxLength={120} />}</Field>
      <Field label="Category">
        {(p) => (
          <Select {...p} value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            {REPORT_CATEGORIES.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </Select>
        )}
      </Field>
      <Field label="What happened?" className="sm:col-span-2" error={error}>
        {(p) => <Textarea {...p} value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} maxLength={2000} className="min-h-32" />}
      </Field>
      <div className="sm:col-span-2">
        <Button type="submit" loading={busy} icon={<LifeBuoy aria-hidden className="size-4" />}>
          Send report
        </Button>
      </div>
    </form>
  )
}
