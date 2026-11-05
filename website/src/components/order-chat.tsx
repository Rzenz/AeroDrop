import { Lock, Send } from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { useMe } from '@/auth/auth'
import { api } from '@/data/api'
import { effectiveStatus, formatTime, shortId } from '@/lib/format'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import { cn } from '@/lib/utils'
import type { Order } from '@/types'
import { IconButton } from './ui/button'
import { Avatar, Card } from './ui/primitives'

/**
 * Order chat with the app's rules: only the order's customer and vendor can
 * post, admins read only, it closes once the order ends, nothing is editable.
 */
export function OrderChat({ order }: { order: Order }) {
  const me = useMe()
  const [version, setVersion] = useState(0)
  const msgs = useQuery(() => api.messages(order.id), [order.id, version])
  const [text, setText] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [sending, setSending] = useState(false)
  const listRef = useRef<HTMLOListElement>(null)

  const status = effectiveStatus(order)
  const closed = ['delivered', 'cancelled', 'rejected'].includes(status)
  const awaitingPayment = order.payment_method === 'xendit_online' && order.payment_status !== 'paid'
  const canPost = me.role !== 'admin' && !closed && !awaitingPayment
  // order_chat_screen.dart: the other party's name and avatar come from
  // get_order_counterpart; a neutral role label is the fallback, never a guess.
  const other = useQuery(() => api.chatCounterpart(order.id), [order.id])
  const vendors = useQuery(() => (me.role === 'admin' ? api.vendors() : Promise.resolve([])), [me.role])
  const vendorRow = vendors.data?.find((v) => v.id === order.vendor_id)

  type Party = { name: string; avatar: string | null; role: 'Customer' | 'Vendor' | 'You' }
  const customer: Party =
    me.role === 'user'
      ? { name: me.full_name, avatar: me.avatar_url, role: 'Customer' }
      : { name: (other.data?.role === 'customer' && other.data.name) || order.customer_name || 'Customer', avatar: other.data?.role === 'customer' ? other.data.avatarUrl : null, role: 'Customer' }
  const vendor: Party =
    me.role === 'vendor'
      ? { name: me.business_name || me.full_name, avatar: me.business_logo_url || me.avatar_url, role: 'Vendor' }
      : me.role === 'user'
        ? { name: (other.data?.role === 'vendor' && other.data.name) || order.vendor_name || 'Vendor', avatar: other.data?.role === 'vendor' ? other.data.avatarUrl : null, role: 'Vendor' }
        : { name: vendorRow?.business_name || order.vendor_name || 'Vendor', avatar: vendorRow?.business_logo_url ?? null, role: 'Vendor' }
  const counterpart = me.role === 'vendor' ? customer : vendor
  const partyOf = (senderId: string): Party => (senderId === order.vendor_id ? vendor : customer)

  useEffect(() => api.subscribeMessages(order.id, () => setVersion((v) => v + 1)), [order.id])

  useEffect(() => {
    if (!msgs.data?.length) return
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight })
    if (me.role !== 'admin' && msgs.data.some((m) => m.sender_id !== me.id && !m.read_at)) {
      api.markMessagesRead(order.id).then(invalidate, () => undefined)
    }
  }, [msgs.data, me.id, me.role, order.id])

  async function send(e: FormEvent) {
    e.preventDefault()
    const body = text.trim()
    if (!body) return
    setSending(true)
    setError(null)
    try {
      await api.sendMessage(order.id, body)
      setText('')
      setVersion((v) => v + 1)
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setSending(false)
    }
  }

  return (
    <Card className="flex h-[420px] flex-col">
      <div className="flex items-center gap-3 px-5 pt-4 pb-3 shadow-[inset_0_-1px_0_var(--line)]">
        {me.role === 'admin' ? (
          <div className="flex shrink-0 -space-x-2">
            <Avatar name={customer.name} src={customer.avatar} size={36} className="ring-2 ring-surface" />
            <Avatar name={vendor.name} src={vendor.avatar} size={36} className="rounded-xl ring-2 ring-surface" />
          </div>
        ) : (
          <Avatar name={counterpart.name} src={counterpart.avatar} size={36} className={counterpart.role === 'Vendor' ? 'rounded-xl' : ''} />
        )}
        <div className="min-w-0">
          <h2 className="truncate font-semibold text-ink">{me.role === 'admin' ? `${customer.name} and ${vendor.name}` : counterpart.name}</h2>
          <p className="truncate text-xs text-ink-3">
            {me.role === 'admin' ? 'Read only, for dispute handling' : counterpart.role} · Order {shortId(order.id)}
            {me.role !== 'admin' && closed ? ' · Closed' : ''}
          </p>
        </div>
      </div>
      <ol ref={listRef} aria-label="Messages" aria-live="polite" className="flex flex-1 flex-col gap-2 overflow-y-auto px-4 py-4">
        {msgs.data?.length ? (
          msgs.data.map((m, i, all) => {
            const mine = m.sender_id === me.id
            const party = partyOf(m.sender_id)
            const right = mine || (me.role === 'admin' && m.sender_id === order.user_id)
            // Name on the first message of a run, avatar on the last, like the app.
            const startsRun = all[i - 1]?.sender_id !== m.sender_id
            const endsRun = all[i + 1]?.sender_id !== m.sender_id
            const showAvatar = !mine
            return (
              <li key={m.id} className={cn('flex max-w-[85%] items-end gap-2', right ? 'flex-row-reverse self-end' : 'self-start', startsRun && i > 0 && 'mt-2')}>
                {showAvatar ? (
                  endsRun ? (
                    <Avatar name={party.name} src={party.avatar} size={28} className={cn('mb-4', party.role === 'Vendor' && 'rounded-lg')} />
                  ) : (
                    <span aria-hidden className="w-7 shrink-0" />
                  )
                ) : null}
                <div className={cn('flex min-w-0 flex-col', right ? 'items-end' : 'items-start')}>
                  {startsRun ? (
                    <span className="mb-0.5 px-1 text-[11px] font-medium text-ink-3">
                      {mine ? 'You' : party.name}
                      {!mine && me.role === 'admin' ? <span className="font-normal"> · {party.role}</span> : null}
                    </span>
                  ) : (
                    <span className="sr-only">{mine ? 'You' : party.name}:</span>
                  )}
                  <p className={cn('rounded-2xl px-3.5 py-2 text-sm break-words', mine ? 'rounded-br-md bg-brand text-on-brand' : right ? 'rounded-br-md bg-sunken text-ink' : 'rounded-bl-md bg-sunken text-ink')}>{m.message}</p>
                  <span className="mt-0.5 px-1 text-[10px] text-ink-3 tabular-nums">
                    {formatTime(m.created_at)}
                    {mine && m.read_at ? ' · Seen' : ''}
                  </span>
                </div>
              </li>
            )
          })
        ) : (
          <li className="m-auto text-center text-sm text-ink-3">{awaitingPayment ? 'Chat opens once payment is confirmed.' : 'No messages yet.'}</li>
        )}
      </ol>
      {canPost ? (
        <form onSubmit={send} className="flex items-end gap-2 p-3 shadow-[inset_0_1px_0_var(--line)]">
          <label className="sr-only" htmlFor={`chat-${order.id}`}>
            Message
          </label>
          <textarea
            id={`chat-${order.id}`}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault()
                e.currentTarget.form?.requestSubmit()
              }
            }}
            maxLength={1000}
            rows={1}
            placeholder={me.role === 'admin' ? undefined : `Message ${counterpart.name}`}
            aria-describedby={error ? `chat-err-${order.id}` : undefined}
            className="max-h-28 min-h-11 flex-1 resize-none rounded-xl bg-sunken px-3.5 py-2.5 text-sm text-ink placeholder:text-ink-3 shadow-[inset_0_0_0_1px_var(--line)] focus:shadow-[inset_0_0_0_2px_var(--brand)] focus:outline-none"
          />
          <IconButton type="submit" label="Send message" disabled={sending || !text.trim()} className="size-11 bg-brand text-on-brand hover:bg-brand hover:text-on-brand disabled:opacity-40">
            <Send aria-hidden className="size-4" />
          </IconButton>
        </form>
      ) : (
        <p className="flex items-center justify-center gap-1.5 p-3 text-xs text-ink-3 shadow-[inset_0_1px_0_var(--line)]">
          <Lock aria-hidden className="size-3.5" />
          {me.role === 'admin' ? 'Admins can read but not post.' : awaitingPayment ? 'Waiting for payment.' : 'This conversation is closed.'}
        </p>
      )}
      {error ? (
        <p id={`chat-err-${order.id}`} role="alert" className="px-4 pb-3 text-xs font-medium text-danger">
          {error}
        </p>
      ) : null}
    </Card>
  )
}
