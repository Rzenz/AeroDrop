import { CheckCircle2, LifeBuoy } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { Badge, Card, CardHeader, Field, Input, Select, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { REPORT_CATEGORIES } from '@/lib/constants'
import { shortId, timeAgo } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'

const faq = [
  ['How long does a delivery take?', 'Flight time comes from the real distance between the vendor and your building. Most campus flights take a few minutes once the drone picks up.'],
  ['Can I cancel?', 'Yes, until the vendor marks the order ready for drone pickup. Payment is refunded and stock restored.'],
  ['Why was my order cancelled by weather?', 'When campus weather is Grounded, active orders are cancelled and refunded and drones return to base.'],
  ['How is the delivery fee calculated?', '₱15 base, plus ₱40 per km and ₱10 per kg. Caution weather adds ₱5 and each extra trip adds ₱25.'],
]

export default function Help() {
  const [params] = useSearchParams()
  const reports = useQuery(() => api.reports())
  const [form, setForm] = useState({ subject: '', category: params.get('orderId') ? 'order' : 'general', message: '' })
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const orderId = params.get('orderId') ?? undefined
  const deliveryId = params.get('deliveryId') ?? undefined

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (form.subject.trim().length < 4) return setError('Give the report a short subject.')
    if (form.message.trim().length < 10) return setError('Describe what happened in a sentence or two.')
    setBusy(true)
    try {
      await api.submitReport({ ...form, orderId, deliveryId })
      invalidate()
      setForm({ subject: '', category: 'general', message: '' })
      toast('Report sent. You will be notified when an admin resolves it.')
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
      <div className="flex flex-col gap-6">
        <Card>
          <CardHeader title="Report a problem" description={orderId ? `About order ${shortId(orderId)}.` : 'An administrator reads every report.'} />
          <form onSubmit={submit} noValidate className="grid gap-4 p-5 sm:grid-cols-2">
            <Field label="Subject">{(p) => <Input {...p} value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} maxLength={120} />}</Field>
            <Field label="Category">
              {(p) => (
                <Select {...p} value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                  {REPORT_CATEGORIES.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
                </Select>
              )}
            </Field>
            <Field label="What happened?" className="sm:col-span-2" error={error}>{(p) => <Textarea {...p} value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} maxLength={2000} className="min-h-32" />}</Field>
            <div className="sm:col-span-2">
              <Button type="submit" loading={busy} icon={<LifeBuoy aria-hidden className="size-4" />}>Send report</Button>
            </div>
          </form>
        </Card>
        <Card>
          <CardHeader title="Common questions" />
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
      <Card className="self-start">
        <CardHeader title="Your reports" />
        <ul className="p-3">
          {(reports.data ?? []).map((r) => (
            <li key={r.id} className="rounded-xl px-3 py-3">
              <div className="flex items-center justify-between gap-2">
                <span className="font-medium text-ink">{r.subject}</span>
                <Badge tone={r.status === 'resolved' ? 'success' : 'warning'}>{r.status === 'resolved' ? 'Resolved' : 'Open'}</Badge>
              </div>
              <p className="mt-0.5 text-xs text-ink-3">{timeAgo(r.created_at)}</p>
              {r.status === 'resolved' && r.admin_notes ? (
                <p className="mt-2 flex gap-2 rounded-lg bg-success-bg px-3 py-2 text-sm text-success"><CheckCircle2 aria-hidden className="mt-0.5 size-4 shrink-0" />{r.admin_notes}</p>
              ) : null}
            </li>
          ))}
          {reports.data && !reports.data.length ? <li className="px-3 py-6 text-center text-sm text-ink-3">You haven’t filed any reports.</li> : null}
        </ul>
      </Card>
    </div>
  )
}
