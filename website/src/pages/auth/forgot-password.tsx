import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { Field, Input } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { errorMessage } from '@/lib/store'
import { AuthShell, CodeInput } from './auth-shell'

export default function ForgotPassword() {
  const navigate = useNavigate()
  const [step, setStep] = useState<'email' | 'reset'>('email')
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [googleOnly, setGoogleOnly] = useState(false)

  async function send(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!/^\S+@\S+\.\S+$/.test(email)) return setError('Enter the email you registered with.')
    setBusy(true)
    try {
      // forgot_password_screen.dart: Google-created accounts can set a password with the code.
      setGoogleOnly(await api.isGoogleOnlyAccount(email).catch(() => false))
      await api.sendPasswordReset(email)
      setStep('reset')
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  async function reset(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (code.length !== 6) return setError('Enter all 6 digits of the code.')
    if (password.length < 6) return setError('Password must be at least 6 characters.')
    setBusy(true)
    try {
      await api.resetPassword(email, code, password)
      toast('Password updated. Sign in with your new password.')
      navigate('/sign-in', { replace: true })
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthShell
      onBack={
        step === 'reset'
          ? () => {
              setStep('email')
              setCode('')
              setError(null)
            }
          : undefined
      }
      title={step === 'email' ? 'Reset your password' : 'Choose a new password'}
      subtitle={step === 'email' ? 'We will email you a 6-digit code.' : <>Enter the code sent to <b className="text-ink">{email}</b>.</>}
      footer={<Link to="/sign-in" className="font-semibold text-brand-ink hover:underline">Back to sign in</Link>}
    >
      {step === 'email' ? (
        <form onSubmit={send} noValidate className="flex flex-col gap-5">
          <Field label="Email" error={error}>{(p) => <Input {...p} type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />}</Field>
          <Button type="submit" size="lg" loading={busy}>
            Send code
          </Button>
        </form>
      ) : (
        <form onSubmit={reset} noValidate className="flex flex-col gap-5">
            {googleOnly ? (
            <div className="rounded-xl bg-sunken px-4 py-3 text-sm">
              <p className="font-semibold text-ink">Google-Created Account</p>
              <p className="mt-0.5 text-ink-2">This account was created with Google sign-in. You can sign in directly with Google or enter this recovery code to set a password for email login.</p>
            </div>
          ) : null}
          <Field label="Reset code">{(p) => <CodeInput id={p.id} value={code} onChange={setCode} />}</Field>
          <Field label="New password" hint="At least 6 characters.">{(p) => <Input {...p} type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} />}</Field>
          {error ? <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 text-sm font-medium text-danger">{error}</p> : null}
          <Button type="submit" size="lg" loading={busy}>
            Update password
          </Button>
        </form>
      )}
    </AuthShell>
  )
}
