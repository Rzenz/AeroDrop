import { BadgeCheck, MailWarning } from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { useAuth } from '@/auth/auth'
import { Button } from '@/components/ui/button'
import { Dialog } from '@/components/ui/dialog'
import { Field } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { CodeInput, FormNote, ResendCode } from '@/pages/auth/auth-shell'
import { errorMessage } from '@/lib/store'
import { needsEmailVerification } from '@/lib/email-verification'
import type { Profile } from '@/types'

/**
 * The "enter your code" card. Opening it emails a fresh 6-digit code to the
 * account's address; verifying it marks the email verified in the database.
 */
export function VerifyEmailDialog({ open, onOpenChange, email }: { open: boolean; onOpenChange: (v: boolean) => void; email: string }) {
  const { refresh } = useAuth()
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [sendError, setSendError] = useState<string | null>(null)
  const [sending, setSending] = useState(false)
  const [sent, setSent] = useState(false)
  const [busy, setBusy] = useState(false)
  const [cooldown, setCooldown] = useState(0)
  const opened = useRef(false)

  useEffect(() => {
    if (cooldown <= 0) return
    const id = setTimeout(() => setCooldown((c) => c - 1), 1000)
    return () => clearTimeout(id)
  }, [cooldown])

  async function send() {
    setSending(true)
    setSendError(null)
    setError(null)
    try {
      await api.sendEmailVerificationCode()
      setSent(true)
      setCooldown(60)
    } catch (err) {
      setSendError(errorMessage(err))
    } finally {
      setSending(false)
    }
  }

  // A code goes out each time the card opens (respecting the cooldown).
  useEffect(() => {
    if (open && !opened.current) {
      opened.current = true
      setCode('')
      setError(null)
      if (cooldown <= 0) void send()
    }
    if (!open) opened.current = false
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  async function verify(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (code.length !== 6) return setError('Enter all 6 digits.')
    setBusy(true)
    try {
      await api.verifyEmailCode(code)
      await refresh()
      toast('Email verified. You can now place orders.')
      onOpenChange(false)
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange} title="Verify your email" className="max-w-md">
      <form onSubmit={verify} noValidate className="flex flex-col gap-4">
        <p className="text-sm text-pretty text-ink-2">
          {sending && !sent ? 'Sending a 6-digit code to ' : 'Enter the 6-digit code we sent to '}
          <b className="font-semibold break-words text-ink">{email}</b>.
        </p>
        {sendError ? <FormNote tone="error">{sendError}</FormNote> : null}
        <Field label="Verification code" error={error}>
          {(p) => <CodeInput id={p.id} value={code} onChange={setCode} invalid={!!error} describedBy={p['aria-describedby']} />}
        </Field>
        <Button type="submit" size="lg" loading={busy} disabled={!sent && !sendError} className="w-full">
          Verify email
        </Button>
        <ResendCode cooldown={cooldown} busy={sending} onResend={send} />
        <p className="text-center text-xs text-ink-3">Check your spam folder if it isn't in your inbox.</p>
      </form>
    </Dialog>
  )
}

/** Shown across the customer and vendor portals until the email is verified. */
export function VerifyEmailBanner({ me }: { me: Profile }) {
  const [open, setOpen] = useState(false)
  if (!needsEmailVerification(me)) return null
  return (
    <>
      <div role="status" className="mx-auto mb-4 flex w-full max-w-7xl flex-col gap-3 rounded-2xl bg-warning-bg px-4 py-3 sm:flex-row sm:items-center">
        <MailWarning aria-hidden className="hidden size-5 shrink-0 text-warning sm:block" />
        <p className="flex-1 text-sm text-pretty text-ink">
          <b className="font-semibold">Verify your email to start ordering.</b>{' '}
          <span className="text-ink-2">
            We'll send a 6-digit code to <span className="break-words">{me.email}</span>.
          </span>
        </p>
        <Button size="sm" onClick={() => setOpen(true)} className="shrink-0 self-start sm:self-auto">
          Verify email
        </Button>
      </div>
      <VerifyEmailDialog open={open} onOpenChange={setOpen} email={me.email} />
    </>
  )
}

/** Profile row: verified badge, or the button that opens the code card. */
export function EmailVerificationStatus({ me }: { me: Profile }) {
  const [open, setOpen] = useState(false)
  if (me.role === 'admin' || me.email_verified_at === undefined) return null
  if (me.email_verified_at) {
    return (
      <p className="inline-flex items-center gap-1.5 text-xs font-semibold text-success">
        <BadgeCheck aria-hidden className="size-4" /> Email verified
      </p>
    )
  }
  return (
    <>
      <div className="flex flex-col items-center gap-2">
        <p className="inline-flex items-center gap-1.5 text-xs font-semibold text-warning">
          <MailWarning aria-hidden className="size-4" /> Email not verified
        </p>
        <Button size="sm" onClick={() => setOpen(true)}>
          Verify email
        </Button>
      </div>
      <VerifyEmailDialog open={open} onOpenChange={setOpen} email={me.email} />
    </>
  )
}
