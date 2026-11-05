import { ImagePlus, X } from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { homeFor, markUnlocked, useAuth } from '@/auth/auth'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Button } from '@/components/ui/button'
import { Field, Input, Select, Textarea } from '@/components/ui/primitives'
import { api } from '@/data/api'
import { VENDOR_CATEGORIES } from '@/lib/constants'
import { isHub } from '@/lib/flight'
import { normalizePhone } from '@/lib/phone'
import { errorMessage, useQuery } from '@/lib/store'
import { AuthShell, CodeInput, GoogleButton, OrDivider } from './auth-shell'

type Role = 'user' | 'vendor'

export default function SignUp() {
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const { refresh } = useAuth()
  const locations = useQuery(() => api.locations())
  const [role, setRole] = useState<Role>(params.get('role') === 'vendor' ? 'vendor' : 'user')
  const [form, setForm] = useState({ fullName: '', email: '', phone: '', password: '', confirm: '', businessName: '', businessCategory: VENDOR_CATEGORIES[0]!, otherCategory: '', businessDescription: '', campusLocationId: '' })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [formError, setFormError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [step, setStep] = useState<'form' | 'code'>('form')
  const [code, setCode] = useState('')
  const [logo, setLogo] = useState<File | null>(null)
  const logoInput = useRef<HTMLInputElement>(null)
  const [cooldown, setCooldown] = useState(0)
  const [resending, setResending] = useState(false)
  const [google, setGoogle] = useState(false)

  const logoPreview = useMemo(() => (logo ? URL.createObjectURL(logo) : null), [logo])
  useEffect(() => () => void (logoPreview && URL.revokeObjectURL(logoPreview)), [logoPreview])

  // otp_email_sent_screen.dart: a new code can be requested every 60 seconds.
  useEffect(() => {
    if (cooldown <= 0) return
    const id = setTimeout(() => setCooldown((c) => c - 1), 1000)
    return () => clearTimeout(id)
  }, [cooldown])

  const set = (k: keyof typeof form) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }))
  const stalls = (locations.data ?? []).filter((l) => !isHub(l))

  function validate() {
    const e: Record<string, string> = {}
    if (form.fullName.trim().length < 2) e.fullName = 'Enter your full name.'
    if (!/^\S+@\S+\.\S+$/.test(form.email)) e.email = 'Enter a valid email address.'
    if (!normalizePhone(form.phone)) e.phone = 'Use a PH mobile number, like 0917 123 4567.'
    if (form.password.length < 6) e.password = 'Password must be at least 6 characters.'
    if (form.confirm !== form.password) e.confirm = 'Passwords do not match.'
    if (role === 'vendor') {
      if (form.businessName.trim().length < 2) e.businessName = 'Enter your store name.'
      if (form.businessCategory === 'Other' && !form.otherCategory.trim()) e.otherCategory = 'Name your category.'
      if (!form.campusLocationId) e.campusLocationId = 'Choose where your stall is.'
    }
    setErrors(e)
    return Object.keys(e).length === 0
  }

  async function submit(ev: FormEvent) {
    ev.preventDefault()
    setFormError(null)
    if (!validate()) return
    setBusy(true)
    try {
      await api.signUp({
        fullName: form.fullName,
        email: form.email,
        password: form.password,
        phone: normalizePhone(form.phone)!,
        role,
        ...(role === 'vendor'
          ? {
              businessName: form.businessName,
              businessCategory: form.businessCategory === 'Other' ? form.otherCategory.trim() : form.businessCategory,
              businessDescription: form.businessDescription,
              campusLocationId: form.campusLocationId,
            }
          : {}),
      })
      setStep('code')
      setCooldown(60)
    } catch (err) {
      setFormError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  async function verify(ev: FormEvent) {
    ev.preventDefault()
    setFormError(null)
    if (code.length !== 6) return setFormError('Enter all 6 digits.')
    setBusy(true)
    try {
      await api.verifySignUpCode(form.email, code)
      const id = await api.currentUserId()
      if (id) markUnlocked(id)
      // The app uploads the picked logo once the account has a session.
      if (role === 'vendor' && logo) await api.uploadStoreLogo(logo, 'business_logo').catch(() => undefined)
      await refresh()
      const profile = id ? await api.profile(id) : null
      navigate(profile ? homeFor(profile) : '/sign-in', { replace: true })
    } catch (err) {
      setFormError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  if (step === 'code') {
    return (
      <AuthShell
        title="Verify your email"
        subtitle={<>Enter the 6-digit code we sent to <b className="text-ink">{form.email}</b>.</>}
        onBack={() => {
          setStep('form')
          setCode('')
          setFormError(null)
        }}
      >
        <form onSubmit={verify} noValidate className="flex flex-col gap-5">
          <Field label="Verification code" error={formError}>
            {(p) => <CodeInput id={p.id} value={code} onChange={setCode} invalid={!!formError} describedBy={p['aria-describedby']} />}
          </Field>
          <Button type="submit" size="lg" loading={busy}>
            {role === 'vendor' ? 'Verify and submit application' : 'Verify and start ordering'}
          </Button>
          <p className="text-center text-sm text-ink-2" aria-live="polite">
            {cooldown > 0 ? (
              <>Resend in <span className="tabular-nums">{cooldown}s</span></>
            ) : (
              <button
                type="button"
                disabled={resending}
                className="font-semibold text-brand-ink hover:underline disabled:opacity-60"
                onClick={async () => {
                  setResending(true)
                  setFormError(null)
                  try {
                    await api.resendSignUpCode(form.email)
                    setCooldown(60)
                  } catch (err) {
                    setFormError(errorMessage(err) || 'Failed to resend verification code. Please try again.')
                  } finally {
                    setResending(false)
                  }
                }}
              >
                {resending ? 'Sending…' : 'Resend Code'}
              </button>
            )}
          </p>
        </form>
      </AuthShell>
    )
  }

  return (
    <AuthShell
      title="Create your account"
      subtitle="One account works in the app and on the web."
      footer={
        <>
          Already registered?{' '}
          <Link to="/sign-in" className="font-semibold text-brand-ink hover:underline">
            Sign in
          </Link>
        </>
      }
    >
      <AnimatedTabs
        label="Account type"
        value={role}
        onChange={setRole}
        tabs={[
          { value: 'user', label: 'Customer' },
          { value: 'vendor', label: 'Vendor' },
        ]}
        className="mb-6"
      />
      {role === 'vendor' ? <p className="-mt-2 mb-6 text-sm text-ink-2">Vendor accounts start as an application. An administrator reviews it before your store goes live.</p> : null}
      <form onSubmit={submit} noValidate className="flex flex-col gap-4">
        <Field label="Full name" error={errors.fullName}>{(p) => <Input {...p} autoComplete="name" value={form.fullName} onChange={set('fullName')} />}</Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Email" error={errors.email}>{(p) => <Input {...p} type="email" autoComplete="email" value={form.email} onChange={set('email')} />}</Field>
          <Field label="Mobile number" error={errors.phone}>{(p) => <Input {...p} type="tel" autoComplete="tel" inputMode="tel" placeholder="0917 123 4567" value={form.phone} onChange={set('phone')} />}</Field>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Password" error={errors.password} hint="At least 6 characters.">{(p) => <Input {...p} type="password" autoComplete="new-password" value={form.password} onChange={set('password')} />}</Field>
          <Field label="Confirm password" error={errors.confirm}>{(p) => <Input {...p} type="password" autoComplete="new-password" value={form.confirm} onChange={set('confirm')} />}</Field>
        </div>

        {role === 'vendor' ? (
          <fieldset className="mt-2 flex flex-col gap-4 rounded-2xl bg-surface p-4 shadow-sm">
            <legend className="sr-only">Store details</legend>
            <p className="text-sm font-semibold text-ink">Store details</p>
            <Field label="Store name" error={errors.businessName}>{(p) => <Input {...p} value={form.businessName} onChange={set('businessName')} />}</Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Category">
                {(p) => (
                  <Select {...p} value={form.businessCategory} onChange={set('businessCategory')}>
                    {VENDOR_CATEGORIES.map((c) => (
                      <option key={c}>{c}</option>
                    ))}
                  </Select>
                )}
              </Field>
              <Field label="Stall location" error={errors.campusLocationId}>
                {(p) => (
                  <Select {...p} value={form.campusLocationId} onChange={set('campusLocationId')}>
                    <option value="">Choose a building</option>
                    {stalls.map((l) => (
                      <option key={l.id} value={l.id}>
                        {l.name}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
            </div>
            {form.businessCategory === 'Other' ? <Field label="Your category" error={errors.otherCategory}>{(p) => <Input {...p} value={form.otherCategory} onChange={set('otherCategory')} />}</Field> : null}
            <Field label="Short description" hint="Optional. Shown on your store page.">{(p) => <Textarea {...p} value={form.businessDescription} onChange={set('businessDescription')} maxLength={300} />}</Field>
            <div>
              <p className="text-sm font-medium text-ink">Business logo <span className="font-normal text-ink-3">(optional)</span></p>
              {logo && logoPreview ? (
                <div className="mt-2 flex items-center gap-3 rounded-xl bg-sunken p-2.5">
                  <img src={logoPreview} alt="" className="size-12 rounded-lg object-cover" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-ink">{logo.name}</p>
                    <p className="text-xs text-ink-3 tabular-nums">{(logo.size / 1024).toFixed(0)} KB</p>
                  </div>
                  <button type="button" onClick={() => logoInput.current?.click()} className="h-9 rounded-lg px-3 text-sm font-semibold text-brand-ink hover:bg-surface">Change</button>
                  <button type="button" onClick={() => setLogo(null)} aria-label="Remove logo" className="grid size-9 place-items-center rounded-lg text-ink-3 hover:bg-surface hover:text-ink"><X aria-hidden className="size-4" /></button>
                </div>
              ) : (
                <button type="button" onClick={() => logoInput.current?.click()} className="mt-2 flex h-20 w-full flex-col items-center justify-center gap-1 rounded-xl border border-dashed border-line text-sm font-semibold text-ink-2 hover:bg-sunken hover:text-ink">
                  <ImagePlus aria-hidden className="size-5" /> Upload a logo
                </button>
              )}
              {errors.logo ? <p className="mt-1.5 text-xs font-medium text-danger">{errors.logo}</p> : <p className="mt-1.5 text-xs text-ink-3">JPEG, PNG or WebP, up to 5 MB.</p>}
              <input
                ref={logoInput}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                className="sr-only"
                tabIndex={-1}
                aria-hidden
                onChange={(e) => {
                  const file = e.target.files?.[0]
                  e.target.value = ''
                  if (!file) return
                  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) return setErrors((x) => ({ ...x, logo: 'Use a JPEG, PNG or WebP image.' }))
                  if (file.size > 5 * 1024 * 1024) return setErrors((x) => ({ ...x, logo: 'Image must be smaller than 5 MB.' }))
                  setErrors((x) => ({ ...x, logo: '' }))
                  setLogo(file)
                }}
              />
            </div>
          </fieldset>
        ) : null}

        {formError ? (
          <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 text-sm font-medium text-danger">
            {formError}
          </p>
        ) : null}
        <Button type="submit" size="lg" loading={busy} className="mt-2">
          {role === 'vendor' ? 'Submit application' : 'Create account'}
        </Button>
        {role === 'user' ? (
          <>
            <OrDivider />
            <GoogleButton
              loading={google}
              onClick={async () => {
                setFormError(null)
                setGoogle(true)
                try {
                  await api.signInWithGoogle()
                } catch (err) {
                  setFormError(errorMessage(err))
                  setGoogle(false)
                }
              }}
            />
          </>
        ) : null}
        <p className="text-center text-xs text-ink-3">
          By signing up you agree to the{' '}
          <Link to="/terms" className="underline">Terms</Link> and{' '}
          <Link to="/privacy" className="underline">Privacy Policy</Link>.
        </p>
      </form>
    </AuthShell>
  )
}
