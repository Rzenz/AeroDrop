import { Lock, Mail } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { homeFor, markUnlocked, useAuth } from '@/auth/auth'
import { Button } from '@/components/ui/button'
import { Field } from '@/components/ui/primitives'
import { api, EmailNotVerifiedError } from '@/data/api'
import { isAdminEmail } from '@/lib/config'
import { errorMessage } from '@/lib/store'
import { AuthInput, AuthShell, CodeInput, FormNote, GoogleButton, OrDivider, PasswordInput, ResendCode } from './auth-shell'

/**
 * login_screen.dart. Password first; then customers and vendors confirm with
 * an emailed code. An email that never finished sign-up gets its sign-up code
 * instead (AuthNotifier.login), so the account can be verified from here.
 */
type Step = 'password' | 'login-code' | 'signup-code'

export default function SignIn() {
  const { user, ready, refresh } = useAuth()
  const navigate = useNavigate()
  const [step, setStep] = useState<Step>('password')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [google, setGoogle] = useState(false)
  const [cooldown, setCooldown] = useState(0)
  const [resending, setResending] = useState(false)

  // otp_email_sent_screen.dart: a new code can be requested every 60 seconds.
  useEffect(() => {
    if (cooldown <= 0) return
    const id = setTimeout(() => setCooldown((c) => c - 1), 1000)
    return () => clearTimeout(id)
  }, [cooldown])

  if (ready && user && step === 'password') return <Navigate to={homeFor(user)} replace />

  function toCodeStep(next: Step, message: string | null) {
    setStep(next)
    setCode('')
    setError(null)
    setNotice(message)
    setCooldown(60)
  }

  function backToPassword() {
    // Drop any half-finished session so the password step starts clean.
    if (step === 'login-code') api.signOut()
    setStep('password')
    setCode('')
    setError(null)
    setNotice(null)
  }

  async function submitPassword(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) return setError('Enter the email you registered with.')
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
      // Migration 35: an unverified account goes straight in and verifies
      // from its profile (it can't order until then). Verified accounts
      // still confirm every sign-in with an emailed code, as in the app.
      if (profile.email_verified_at === null) {
        markUnlocked(profile.id)
        await refresh()
        navigate(homeFor(profile), { replace: true })
        return
      }
      await api.sendLoginCode(email)
      toCodeStep('login-code', null)
    } catch (err) {
      if (err instanceof EmailNotVerifiedError) toCodeStep('signup-code', err.message)
      else setError(errorMessage(err))
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
      if (step === 'signup-code') await api.verifySignUpCode(email, code)
      else await api.verifyLoginCode(email, code)
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

  async function resend() {
    setResending(true)
    setError(null)
    try {
      if (step === 'signup-code') await api.resendSignUpCode(email)
      else await api.sendLoginCode(email)
      setNotice('We sent you a new code.')
      setCooldown(60)
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setResending(false)
    }
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

  if (step !== 'password') {
    return (
      <AuthShell
        title={step === 'signup-code' ? 'Verify your email' : 'Check your email'}
        subtitle={
          <>
            Enter the 6-digit code we sent to <b className="font-semibold break-words text-ink">{email.trim().toLowerCase()}</b>.
          </>
        }
        onBack={backToPassword}
      >
        <form onSubmit={submitCode} noValidate className="flex flex-col gap-5">
          {notice ? <FormNote tone="info">{notice}</FormNote> : null}
          <Field label={step === 'signup-code' ? 'Verification code' : 'Sign-in code'} error={error}>
            {(p) => <CodeInput id={p.id} value={code} onChange={setCode} invalid={!!error} describedBy={p['aria-describedby']} />}
          </Field>
          <Button type="submit" size="lg" loading={busy} className="w-full">
            Verify and continue
          </Button>
          <ResendCode cooldown={cooldown} busy={resending} onResend={resend} />
          <button type="button" onClick={backToPassword} className="self-center text-sm text-ink-2 hover:text-ink">
            Use another account
          </button>
        </form>
      </AuthShell>
    )
  }

  return (
    <AuthShell
      split
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
        <Field label="Email">
          {(p) => <AuthInput {...p} icon={<Mail aria-hidden />} type="email" autoComplete="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@example.com" />}
        </Field>
        <div className="flex flex-col gap-1.5">
          <Field label="Password">{(p) => <PasswordInput {...p} icon={<Lock aria-hidden />} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Your password" />}</Field>
          <Link to="/forgot-password" className="self-end text-sm font-semibold text-brand-ink hover:underline">
            Forgot password?
          </Link>
        </div>
        {error ? <FormNote tone="error">{error}</FormNote> : null}
        <Button type="submit" size="lg" loading={busy} className="w-full">
          Sign in
        </Button>
        <OrDivider />
        <GoogleButton onClick={continueWithGoogle} loading={google} />
      </form>
    </AuthShell>
  )
}
