import { Eye, EyeOff } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { homeFor, markUnlocked, useAuth } from '@/auth/auth'
import { Button } from '@/components/ui/button'
import { Field, Input } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { isAdminEmail } from '@/lib/config'
import { errorMessage } from '@/lib/store'
import { AuthShell, CodeInput, GoogleButton, OrDivider } from './auth-shell'

export default function SignIn() {
  const { user, ready, refresh } = useAuth()
  const navigate = useNavigate()
  const [step, setStep] = useState<'password' | 'code'>('password')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [google, setGoogle] = useState(false)

  if (ready && user && step === 'password') return <Navigate to={homeFor(user)} replace />

  async function submitPassword(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!/^\S+@\S+\.\S+$/.test(email)) return setError('Enter the email you registered with.')
    if (!password) return setError('Enter your password.')
    setBusy(true)
    try {
      const profile = await api.signIn(email, password)
      if (profile.role === 'admin' || isAdminEmail(profile.email)) {
        markUnlocked(profile.id)
        await refresh()
        navigate(homeFor(profile), { replace: true })
        return
      }
      // Customers and vendors confirm with an emailed code, as in the app.
      await api.sendLoginCode(email)
      setStep('code')
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  async function submitCode(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (code.length !== 6) return setError('Enter all 6 digits.')
    setBusy(true)
    try {
      await api.verifyLoginCode(email, code)
      const id = await api.currentUserId()
      if (id) markUnlocked(id)
      await refresh()
      const profile = id ? await api.profile(id) : null
      navigate(profile ? homeFor(profile) : '/', { replace: true })
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  if (step === 'code') {
    return (
      <AuthShell
        title="Check your email"
        subtitle={<>We sent a 6-digit code to <b className="text-ink">{email}</b>.</>}
        onBack={() => {
          // Drop the half-finished session so the password step starts clean.
          api.signOut()
          setStep('password')
          setCode('')
          setError(null)
        }}
      >
        <form onSubmit={submitCode} noValidate className="flex flex-col gap-5">
          <Field label="Sign-in code" error={error}>
            {(p) => <CodeInput id={p.id} value={code} onChange={setCode} invalid={!!error} describedBy={p['aria-describedby']} />}
          </Field>
          <Button type="submit" size="lg" loading={busy}>
            Verify and continue
          </Button>
          <div className="flex justify-between text-sm">
            <button type="button" className="font-semibold text-brand-ink hover:underline" onClick={() => api.sendLoginCode(email).catch((err) => setError(errorMessage(err)))}>
              Send a new code
            </button>
            <button
              type="button"
              className="text-ink-2 hover:text-ink"
              onClick={() => {
                api.signOut()
                setStep('password')
                setCode('')
              }}
            >
              Use another account
            </button>
          </div>
        </form>
      </AuthShell>
    )
  }

  // login_screen.dart _continueWithGoogle: Google creates customer accounts;
  // the browser comes back to /auth/callback to finish.
  async function continueWithGoogle() {
    setError(null)
    setGoogle(true)
    try {
      await api.signInWithGoogle()
    } catch (err) {
      setError(errorMessage(err))
      setGoogle(false)
    }
  }

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in with the account you use in the AeroDrop app."
      footer={
        <>
          New to AeroDrop?{' '}
          <Link to="/sign-up" className="font-semibold text-brand-ink hover:underline">
            Create an account
          </Link>
        </>
      }
    >
      <form onSubmit={submitPassword} noValidate className="flex flex-col gap-5">
        <Field label="Email">{(p) => <Input {...p} type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@uclm.edu.ph" />}</Field>
        <Field label="Password">
          {(p) => (
            <div className="relative">
              <Input {...p} type={show ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} className="pr-12" />
              <button type="button" onClick={() => setShow((v) => !v)} aria-label={show ? 'Hide password' : 'Show password'} className="absolute top-1/2 right-1.5 grid size-9 -translate-y-1/2 place-items-center rounded-lg text-ink-3 hover:text-ink">
                {show ? <EyeOff aria-hidden className="size-4" /> : <Eye aria-hidden className="size-4" />}
              </button>
            </div>
          )}
        </Field>
        {error ? (
          <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 text-sm font-medium text-danger">
            {error}
          </p>
        ) : null}
        <Button type="submit" size="lg" loading={busy}>
          Sign in
        </Button>
        <OrDivider />
        <GoogleButton onClick={continueWithGoogle} loading={google} />
        <Link to="/forgot-password" className="self-center text-sm font-semibold text-brand-ink hover:underline">
          Forgot password?
        </Link>
      </form>
    </AuthShell>
  )
}
