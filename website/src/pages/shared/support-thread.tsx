import { ArrowLeft, CircleCheck, ImageOff, ImagePlus, Inbox, RotateCw, Send, X } from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { IconButton } from '@/components/ui/button'
import { Dialog } from '@/components/ui/dialog'
import { PageLoader, Spinner } from '@/components/ui/loader'
import { Badge, Card, EmptyState, ErrorNote } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { reportCategoryLabel, SUPPORT_MAX_PHOTOS, SUPPORT_MESSAGE_MAX } from '@/lib/constants'
import { formatDateTime, formatTime, shortId } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { SupportReport } from '@/types'

const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp']

/**
 * support_thread_screen.dart: one support report as a conversation. The
 * report's own message opens the thread; replies come from support_messages
 * with up to three private photos each. A reporter replying to a resolved
 * report reopens it (server side, migration 28); an admin's reply does not.
 */
export default function SupportThread() {
  const { reportId = '' } = useParams()
  const me = useMe()
  const report = useQuery(() => api.report(reportId), [reportId])
  const back = me.role === 'admin' ? { to: '/admin/support', label: 'Support' } : { to: `/${me.role}/help`, label: 'Help & Support' }

  if (report.loading) return <PageLoader />
  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-5">
      <Link to={back.to} className="inline-flex w-fit items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
        <ArrowLeft aria-hidden className="size-4" /> {back.label}
      </Link>
      {report.error ? (
        <ErrorNote message="Could not load this report." onRetry={report.reload} />
      ) : !report.data ? (
        <Card>
          <EmptyState icon={<Inbox aria-hidden className="size-5" />} title="Report not found" body="It may have been removed, or it belongs to someone else." />
        </Card>
      ) : (
        <Thread report={report.data} onReportChanged={report.reload} />
      )}
    </div>
  )
}

function Thread({ report, onReportChanged }: { report: SupportReport; onReportChanged: () => void }) {
  const me = useMe()
  const [version, setVersion] = useState(0)
  const messages = useQuery(() => api.supportMessages(report.id), [report.id, version])
  const reporter = useQuery(() => (report.user_id === me.id ? Promise.resolve('You') : api.supportUserName(report.user_id)), [report.user_id, me.id])
  const isReporter = report.user_id === me.id
  const reporterName = reporter.data ?? 'Reporter'
  const resolved = report.status === 'resolved'
  const listRef = useRef<HTMLOListElement>(null)

  // Realtime inserts reload the thread; the report reloads too, since a
  // reporter's reply may have reopened it.
  useEffect(
    () =>
      api.subscribeSupportMessages(report.id, () => {
        setVersion((v) => v + 1)
        onReportChanged()
      }),
    [report.id, onReportChanged],
  )

  // Read on open, and again whenever the other side's messages arrive unread.
  const unread = (messages.data ?? []).some((m) => m.sender_id !== me.id && !m.read_at)
  useEffect(() => {
    if (messages.loading) return
    if (unread || version === 0) api.markSupportRead(report.id).then(invalidate, () => undefined)
  }, [unread, messages.loading, report.id, version])

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight })
  }, [messages.data?.length])

  return (
    <Card className="flex h-[calc(100dvh-11rem)] min-h-[480px] flex-col overflow-hidden">
      <header className="flex items-start justify-between gap-3 px-5 pt-4 pb-3 shadow-[inset_0_-1px_0_var(--line)]">
        <div className="min-w-0">
          <h2 className="truncate font-display text-lg font-bold text-ink">{report.subject || 'Support report'}</h2>
          <p className="truncate text-xs text-ink-3">
            {reportCategoryLabel(report.category)} · Report {shortId(report.id)}
            {me.role === 'admin' ? ` · ${reporterName}` : ''}
            {report.order_id ? (
              <>
                {' · '}
                <Link to={me.role === 'admin' ? `/admin/deliveries/details?id=${report.order_id}` : `/${me.role}/orders/${report.order_id}`} className="font-semibold text-brand-ink hover:underline">
                  Order {shortId(report.order_id)}
                </Link>
              </>
            ) : null}
          </p>
        </div>
        <Badge tone={resolved ? 'success' : 'warning'} dot>
          {resolved ? 'Resolved' : 'Open'}
        </Badge>
      </header>

      <ol ref={listRef} aria-label="Support conversation" aria-live="polite" className="flex flex-1 flex-col gap-3 overflow-y-auto px-4 py-4">
        <Bubble label={`Original report · ${reporterName}`} text={report.message} createdAt={report.created_at} mine={isReporter} />
        {messages.error && !messages.data ? (
          <li className="m-auto">
            <ErrorNote message="Could not load messages." onRetry={messages.reload} />
          </li>
        ) : messages.loading && !messages.data ? (
          <li className="m-auto">
            <Spinner />
          </li>
        ) : messages.data?.length ? (
          messages.data.map((m) => {
            const mine = m.sender_id === me.id
            // Anyone other than the reporter is an admin, shown as "Support".
            const label = mine ? 'You' : m.sender_id === report.user_id ? reporterName : 'Support'
            return <Bubble key={m.id} label={label} text={m.message} createdAt={m.created_at} mine={mine} attachments={m.attachments} seen={mine && !!m.read_at} />
          })
        ) : (
          <li className="py-2 text-center text-xs text-ink-3">{isReporter ? 'No replies yet. Support will answer here.' : 'No replies yet.'}</li>
        )}
      </ol>

      <Composer
        report={report}
        isReporter={isReporter}
        onSent={(reopened) => {
          setVersion((v) => v + 1)
          if (reopened) onReportChanged()
          invalidate()
        }}
      />
    </Card>
  )
}

function Bubble({ label, text, createdAt, mine, attachments = [], seen }: { label: string; text: string; createdAt: string; mine: boolean; attachments?: string[]; seen?: boolean }) {
  return (
    <li className={cn('flex max-w-[85%] flex-col', mine ? 'items-end self-end' : 'items-start self-start')}>
      <span className="mb-0.5 px-1 text-[11px] font-medium text-ink-3">{label}</span>
      {text.trim() ? <p className={cn('rounded-2xl px-3.5 py-2 text-sm break-words whitespace-pre-line', mine ? 'rounded-br-md bg-brand text-on-brand' : 'rounded-bl-md bg-sunken text-ink')}>{text}</p> : null}
      {attachments.length ? (
        <ul className={cn('mt-1.5 flex flex-wrap gap-1.5', mine && 'justify-end')} aria-label={`${attachments.length} photo${attachments.length === 1 ? '' : 's'}`}>
          {attachments.map((path, i) => (
            <li key={path}>
              <Attachment path={path} index={i + 1} />
            </li>
          ))}
        </ul>
      ) : null}
      <time dateTime={createdAt} title={formatDateTime(createdAt)} className="mt-0.5 px-1 text-[10px] text-ink-3 tabular-nums">
        {formatTime(createdAt)}
        {seen ? ' · Seen' : ''}
      </time>
    </li>
  )
}

/** A private photo, shown through a signed URL; opens larger in a dialog. */
function Attachment({ path, index }: { path: string; index: number }) {
  const [attempt, setAttempt] = useState(0)
  const url = useQuery(() => api.supportAttachmentUrl(path), [path, attempt])
  const [open, setOpen] = useState(false)
  const [broken, setBroken] = useState(false)

  if (url.error || broken) {
    return (
      <button
        type="button"
        onClick={() => {
          setBroken(false)
          setAttempt((a) => a + 1)
        }}
        className="grid size-24 place-items-center rounded-xl bg-sunken p-2 text-center text-[11px] text-ink-3 hover:text-ink"
      >
        <span className="flex flex-col items-center gap-1">
          <RotateCw aria-hidden className="size-4" />
          Could not load. Tap to retry.
        </span>
      </button>
    )
  }
  if (!url.data) return <span aria-hidden className="block size-24 animate-pulse rounded-xl bg-sunken" />
  return (
    <>
      <button type="button" onClick={() => setOpen(true)} aria-label={`Open photo ${index}`} className="block overflow-hidden rounded-xl transition-[scale] duration-150 active:scale-[0.96]">
        <img src={url.data} alt="" onError={() => setBroken(true)} className="size-24 object-cover outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10" />
      </button>
      {open ? (
        <Dialog open onOpenChange={setOpen} title={`Photo ${index}`} className="max-w-3xl">
          <img src={url.data} alt={`Attached photo ${index}`} className="max-h-[70dvh] w-full rounded-xl object-contain" />
        </Dialog>
      ) : null}
    </>
  )
}

function Composer({ report, isReporter, onSent }: { report: SupportReport; isReporter: boolean; onSent: (reopened: boolean) => void }) {
  const [text, setText] = useState('')
  const [photos, setPhotos] = useState<File[]>([])
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)
  const previews = useMemo(() => photos.map((f) => URL.createObjectURL(f)), [photos])
  useEffect(() => () => previews.forEach((u) => URL.revokeObjectURL(u)), [previews])

  const resolved = report.status === 'resolved'
  const full = photos.length >= SUPPORT_MAX_PHOTOS
  const canSend = (text.trim().length > 0 || photos.length > 0) && !sending
  const near = text.length > SUPPORT_MESSAGE_MAX - 200

  function addPhotos(files: FileList | null) {
    setError(null)
    const picked = [...(files ?? [])]
    for (const f of picked) {
      if (!PHOTO_TYPES.includes(f.type)) return setError('Unsupported image format. Please choose a JPG, PNG, or WebP image.')
      if (f.size > 5 * 1024 * 1024) return setError('Image is too large. Please choose an image under 5 MB.')
    }
    const room = SUPPORT_MAX_PHOTOS - photos.length
    if (picked.length > room) setError(`You can attach up to ${SUPPORT_MAX_PHOTOS} photos per message.`)
    setPhotos((p) => [...p, ...picked.slice(0, room)])
  }

  async function send(e: FormEvent) {
    e.preventDefault()
    if (!canSend) return
    setSending(true)
    setError(null)
    try {
      await api.sendSupportMessage(report.id, text, photos)
      setText('')
      setPhotos([])
      onSent(resolved && isReporter)
    } catch (err) {
      const msg = errorMessage(err)
      setError(msg.startsWith('Photo upload failed') || msg.includes('photo') || msg.includes('Message is too long') || msg.startsWith('Write a message') ? msg : `Message not sent: ${msg}`)
    } finally {
      setSending(false)
    }
  }

  return (
    <form onSubmit={send} className="flex flex-col gap-2 p-3 shadow-[inset_0_1px_0_var(--line)]">
      {resolved ? (
        <p className="flex items-center gap-2 rounded-xl bg-sunken px-3 py-2 text-xs text-ink-2">
          <CircleCheck aria-hidden className="size-4 shrink-0 text-success" />
          {isReporter ? 'This report is resolved. Sending a message will reopen it.' : 'This report is resolved. Your reply will not reopen it.'}
        </p>
      ) : null}
      {photos.length ? (
        <ul className="flex gap-2" aria-label="Photos to send">
          {photos.map((f, i) => (
            <li key={`${f.name}-${i}`} className="relative">
              <img src={previews[i]} alt="" className="size-16 rounded-xl object-cover outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10" />
              <button
                type="button"
                disabled={sending}
                onClick={() => setPhotos((p) => p.filter((_, j) => j !== i))}
                aria-label={`Remove photo ${i + 1}`}
                className="absolute -top-1.5 -right-1.5 grid size-6 place-items-center rounded-full bg-ink text-bg shadow-sm disabled:opacity-50"
              >
                <X aria-hidden className="size-3.5" />
              </button>
            </li>
          ))}
        </ul>
      ) : null}
      <div className="flex items-end gap-2">
        <IconButton
          type="button"
          label={full ? `Up to ${SUPPORT_MAX_PHOTOS} photos` : 'Attach a photo'}
          disabled={full || sending}
          onClick={() => fileInput.current?.click()}
          className="size-11 shrink-0 disabled:opacity-40"
        >
          <ImagePlus aria-hidden className="size-5" />
        </IconButton>
        <input
          ref={fileInput}
          type="file"
          accept={PHOTO_TYPES.join(',')}
          multiple
          className="sr-only"
          tabIndex={-1}
          aria-hidden
          onChange={(e) => {
            addPhotos(e.target.files)
            e.target.value = ''
          }}
        />
        <label className="sr-only" htmlFor={`support-msg-${report.id}`}>
          Message
        </label>
        <textarea
          id={`support-msg-${report.id}`}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault()
              e.currentTarget.form?.requestSubmit()
            }
          }}
          maxLength={SUPPORT_MESSAGE_MAX}
          rows={1}
          disabled={sending}
          placeholder="Write a message"
          aria-describedby={error ? `support-err-${report.id}` : undefined}
          className="max-h-32 min-h-11 flex-1 resize-none rounded-xl bg-sunken px-3.5 py-2.5 text-sm text-ink shadow-[inset_0_0_0_1px_var(--line)] placeholder:text-ink-3 focus:shadow-[inset_0_0_0_2px_var(--brand)] focus:outline-none disabled:opacity-60"
        />
        <IconButton type="submit" label="Send" disabled={!canSend} className="size-11 shrink-0 bg-brand text-on-brand hover:bg-brand hover:text-on-brand disabled:opacity-40">
          {sending ? <Spinner size={16} /> : <Send aria-hidden className="size-4" />}
        </IconButton>
      </div>
      <div className="flex justify-between gap-3 px-1 text-[11px] text-ink-3">
        {error ? (
          <p id={`support-err-${report.id}`} role="alert" className="flex items-center gap-1 font-medium text-danger">
            <ImageOff aria-hidden className="size-3.5 shrink-0" />
            {error}
          </p>
        ) : (
          <span>JPG, PNG or WebP · up to {SUPPORT_MAX_PHOTOS} photos, 5 MB each</span>
        )}
        {near ? <span className="shrink-0 tabular-nums">{text.length}/{SUPPORT_MESSAGE_MAX}</span> : null}
      </div>
    </form>
  )
}
