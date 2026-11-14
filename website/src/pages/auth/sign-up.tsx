import { ImagePlus, Lock, Mail, Phone, Store, UserRound, X } from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { homeFor, markUnlocked, useAuth } from '@/auth/auth'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Button } from '@/components/ui/button'
import { Field, Select, Textarea } from '@/components/ui/primitives'
import { api, EmailRejectedError } from '@/data/api'
import { VENDOR_CATEGORIES } from '@/lib/constants'
import { isHub } from '@/lib/flight'
import { normalizePhone } from '@/lib/phone'
import { errorMessage, useQuery } from '@/lib/store'
import { AuthInput, AuthShell, CodeInput, FormNote, GoogleButton, OrDivider, PasswordInput, PasswordStrengthMeter, ResendCode } from './auth-shell'

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
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [acceptTerms, setAcceptTerms] = useState(false)
  const [step, setStep] = useState<'form' | 'code'>('form')
  // Vendors fill in two short steps so each fits on one screen.
  const [vendorStep, setVendorStep] = useState<1 | 2>(1)
  const [code, setCode] = useState('')
  const [logo, setLogo] = useState<File | null>(null)
  const logoInput = useRef<HTMLInputElement>(null)
  const [cooldown, setCooldown] = useState(0)
  const [resending, setResending] = useState(false)
  const [google, setGoogle] = useState(false)
  // check-email's verdict for the address last checked, shown under the field.
  const [emailCheck, setEmailCheck] = useState<{ email: string; checking: boolean; suggestion?: string } | null>(null)

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

  // The address in the field right now, so a slow check can't overwrite a newer one.
  const latestEmail = useRef('')

  function changeEmail(value: string) {
    latestEmail.current = value.trim().toLowerCase()
    setForm((f) => ({ ...f, email: value }))
    setEmailCheck(null)
    setErrors(({ email: _e, ...rest }) => rest)
  }

  /** On leaving the field: is this a real address that can receive mail? */
  async function checkEmail(value = form.email) {
    const email = value.trim().toLowerCase()
    if (!/^\S+@\S+\.\S+$/.test(email)) return
    setEmailCheck({ email, checking: true })
    const result = await api.checkEmail(email)
    if (latestEmail.current !== email) return
    setEmailCheck({ email, checking: false, suggestion: result.suggestion })
    if (!result.ok) setErrors((x) => ({ ...x, email: result.message ?? "This email address can't receive mail." }))
  }

  /** `account` checks the first step only; `all` adds the store and the terms. */
  function validate(scope: 'account' | 'all') {
    const e: Record<string, string> = {}
    if (form.fullName.trim().length < 2) e.fullName = 'Enter your full name.'
    if (!/^\S+@\S+\.\S+$/.test(form.email)) e.email = 'Enter a valid email address.'
    if (!normalizePhone(form.phone)) e.phone = 'Use a PH mobile number, like 0917 123 4567.'
    if (form.password.length < 6) e.password = 'Password must be at least 6 characters.'
    if (form.confirm !== form.password) e.confirm = 'Passwords do not match.'
    if (scope === 'all' && role === 'vendor') {
      if (form.businessName.trim().length < 2) e.businessName = 'Enter your store name.'
      if (form.businessCategory === 'Other' && !form.otherCategory.trim()) e.otherCategory = 'Name your category.'
      if (!form.campusLocationId) e.campusLocationId = 'Choose where your stall is.'
    }
    // A failed live email check stays an error until the address changes.
    if (errors.email && form.email.trim().toLowerCase() === emailCheck?.email) e.email = errors.email
    // register_screen.dart's two messages.
    if (scope === 'all' && !acceptTerms) e.terms = role === 'vendor' ? 'You must agree to the Terms of Service to list your store.' : 'You must accept the terms & conditions.'
    setErrors(e)
    return e
  }
  const ACCOUNT_FIELDS = ['fullName', 'email', 'phone', 'password', 'confirm']

  async function submit(ev: FormEvent) {
    ev.preventDefault()
    setFormError(null)
    if (role === 'vendor' && vendorStep === 1) {
      if (Object.keys(validate('account')).length === 0) setVendorStep(2)
      return
    }
    const found = validate('all')
    if (Object.keys(found).length) {
      // Anything wrong on the account step sends a vendor back to it.
      if (role === 'vendor' && ACCOUNT_FIELDS.some((k) => k in found)) setVendorStep(1)
      return
    }
    setBusy(true)
    try {
      const result = await api.signUp({
        fullName: form.fullName,
        email: form.email,
        password: form.password,
        phone: normalizePhone(form.phone)!,
        role,
        termsAcceptedAt: new Date().toISOString(),
        ...(role === 'vendor'
          ? {
              businessName: form.businessName,
              businessCategory: form.businessCategory === 'Other' ? form.otherCategory.trim() : form.businessCategory,
              businessDescription: form.businessDescription,
              campusLocationId: form.campusLocationId,
            }
          : {}),
      })
      if (!result.verify) {
        // Email confirmation is off for this project: the account is signed in.
        await finish()
        return
      }
      setNotice(result.notice ?? null)
      setStep('code')
      setCode('')
      setCooldown(60)
    } catch (err) {
      if (err instanceof EmailRejectedError) {
        setErrors((x) => ({ ...x, email: err.message }))
        setEmailCheck({ email: form.email.trim().toLowerCase(), checking: false, suggestion: err.suggestion })
        setFormError('Check your email address above.')
        setVendorStep(1)
      } else setFormError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  /** Signed in: upload the picked logo (as the app does once there is a session) and go home. */
  async function finish() {
    const id = await api.currentUserId()
    if (id) markUnlocked(id)
    if (role === 'vendor' && logo) await api.uploadStoreLogo(logo, 'business_logo').catch(() => undefined)
    await refresh()
    const profile = id ? await api.profile(id) : null
    navigate(profile ? homeFor(profile) : '/sign-in', { replace: true })
  }

  async function resend() {
    setResending(true)
    setFormError(null)
    try {
      await api.resendSignUpCode(form.email)
      setNotice('We sent you a new code.')
      setCooldown(60)
    } catch (err) {
      setFormError(errorMessage(err) || 'Failed to resend verification code. Please try again.')
    } finally {
      setResending(false)
    }
  }

  async function verify(ev: FormEvent) {
    ev.preventDefault()
    setFormError(null)
    if (code.length !== 6) return setFormError('Enter all 6 digits.')
    setBusy(true)
    try {
      await api.verifySignUpCode(form.email, code)
      await finish()
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
        subtitle={
          <>
            Enter the 6-digit code we sent to <b className="font-semibold break-words text-ink">{form.email.trim().toLowerCase()}</b>.
          </>
        }
        onBack={() => {
          setStep('form')
          setCode('')
          setFormError(null)
          setNotice(null)
        }}
      >
        <form onSubmit={verify} noValidate className="flex flex-col gap-5">
          {notice ? <FormNote tone="info">{notice}</FormNote> : null}
          <Field label="Verification code" error={formError}>
            {(p) => <CodeInput id={p.id} value={code} onChange={setCode} invalid={!!formError} describedBy={p['aria-describedby']} />}
          </Field>
          <Button type="submit" size="lg" loading={busy} className="w-full">
            {role === 'vendor' ? 'Verify and submit application' : 'Verify and start ordering'}
          </Button>
          <ResendCode cooldown={cooldown} busy={resending} onResend={resend} />
        </form>
      </AuthShell>
    )
  }

  const accountStep = role === 'user' || vendorStep === 1
  const finalStep = role === 'user' || vendorStep === 2

  return (
    <AuthShell
      split
      wide
      title="Create your account"
      subtitle="One account works in the AeroDrop app and on the web."
      footer={
        <>
          Already registered?{' '}
          <Link to="/sign-in" className="font-semibold text-brand-ink hover:underline">
            Sign in
          </Link>
        </>
      }
    >
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <AnimatedTabs
          label="Account type"
          value={role}
          onChange={(r) => {
            setRole(r)
            setVendorStep(1)
            setFormError(null)
          }}
          tabs={[
            { value: 'user', label: 'Customer' },
            { value: 'vendor', label: 'Vendor' },
          ]}
        />
        {role === 'vendor' ? (
          <p className="text-xs font-semibold text-ink-3">
            Step <span className="tabular-nums">{vendorStep}</span> of 2 · {vendorStep === 1 ? 'Your account' : 'Your store'}
          </p>
        ) : null}
      </div>

      <form onSubmit={submit} noValidate className="flex flex-col gap-3">
        {accountStep ? (
          <>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Full name" error={errors.fullName}>{(p) => <AuthInput {...p} icon={<UserRound aria-hidden />} autoComplete="name" placeholder="Juan dela Cruz" value={form.fullName} onChange={set('fullName')} />}</Field>
              <Field label="Mobile number" error={errors.phone}>{(p) => <AuthInput {...p} icon={<Phone aria-hidden />} type="tel" autoComplete="tel" inputMode="tel" placeholder="0917 123 4567" value={form.phone} onChange={set('phone')} />}</Field>
            </div>
            <div className="flex flex-col gap-1.5">
              <Field label="Email" error={errors.email} hint={emailCheck?.checking ? 'Checking this address…' : undefined}>
                {(p) => <AuthInput {...p} icon={<Mail aria-hidden />} type="email" autoComplete="email" inputMode="email" placeholder="name@example.com" value={form.email} onChange={(e) => changeEmail(e.target.value)} onBlur={() => checkEmail()} />}
              </Field>
              {emailCheck?.suggestion && errors.email ? (
                <button
                  type="button"
                  onClick={() => {
                    const next = emailCheck.suggestion!
                    changeEmail(next)
                    void checkEmail(next)
                  }}
                  className="w-fit text-left text-xs font-semibold text-brand-ink hover:underline"
                >
                  Use {emailCheck.suggestion}
                </button>
              ) : null}
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Password" error={errors.password}>{(p) => <PasswordInput {...p} icon={<Lock aria-hidden />} autoComplete="new-password" placeholder="At least 6 characters" value={form.password} onChange={set('password')} />}</Field>
              <Field label="Confirm password" error={errors.confirm}>{(p) => <PasswordInput {...p} icon={<Lock aria-hidden />} autoComplete="new-password" placeholder="Type it again" value={form.confirm} onChange={set('confirm')} />}</Field>
            </div>
            <PasswordStrengthMeter password={form.password} personal={[form.fullName, form.email, form.businessName]} />
          </>
        ) : (
          <>
            <p className="text-sm text-pretty text-ink-2">Vendor accounts start as an application. An administrator reviews it before your store goes live.</p>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Store name" error={errors.businessName}>{(p) => <AuthInput {...p} icon={<Store aria-hidden />} autoComplete="organization" value={form.businessName} onChange={set('businessName')} />}</Field>
              <Field label="Category">
                {(p) => (
                  <Select {...p} value={form.businessCategory} onChange={set('businessCategory')}>
                    {VENDOR_CATEGORIES.map((c) => (
                      <option key={c}>{c}</option>
                    ))}
                  </Select>
                )}
              </Field>
            </div>
            {form.businessCategory === 'Other' ? <Field label="Your category" error={errors.otherCategory}>{(p) => <AuthInput {...p} value={form.otherCategory} onChange={set('otherCategory')} />}</Field> : null}
            <div className="grid gap-3 sm:grid-cols-2">
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
              <div className="flex flex-col gap-1.5">
                <p className="text-sm font-medium text-ink">
                  Business logo <span className="font-normal text-ink-3">(optional)</span>
                </p>
                {logo && logoPreview ? (
                  <div className="flex h-11 items-center gap-2 rounded-xl bg-sunken ps-1.5 pe-1 shadow-[inset_0_0_0_1px_var(--line)]">
                    <img src={logoPreview} alt="" className="size-8 rounded-lg object-cover" />
                    <p className="min-w-0 flex-1 truncate text-sm text-ink">{logo.name}</p>
                    <button type="button" onClick={() => logoInput.current?.click()} className="h-9 rounded-lg px-2.5 text-sm font-semibold text-brand-ink hover:bg-surface">
                      Change
                    </button>
                    <button type="button" onClick={() => setLogo(null)} aria-label="Remove logo" className="grid size-9 place-items-center rounded-lg text-ink-3 hover:bg-surface hover:text-ink">
                      <X aria-hidden className="size-4" />
                    </button>
                  </div>
                ) : (
                  <button type="button" onClick={() => logoInput.current?.click()} className="flex h-11 items-center justify-center gap-2 rounded-xl border border-dashed border-line text-sm font-semibold text-ink-2 hover:bg-sunken hover:text-ink">
                    <ImagePlus aria-hidden className="size-4" /> Upload a logo
                  </button>
                )}
                {errors.logo ? <p className="text-xs font-medium text-danger">{errors.logo}</p> : null}
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
            </div>
            <Field label="Short description" hint="Optional. Shown on your store page.">{(p) => <Textarea {...p} value={form.businessDescription} onChange={set('businessDescription')} maxLength={300} className="min-h-[72px]" />}</Field>
          </>
        )}

        {finalStep ? (
          <div className="mt-1">
            <label className="flex cursor-pointer items-start gap-3 text-sm text-ink-2">
              <input
                type="checkbox"
                checked={acceptTerms}
                onChange={(e) => {
                  setAcceptTerms(e.target.checked)
                  if (e.target.checked) setErrors(({ terms: _t, ...rest }) => rest)
                }}
                aria-invalid={!!errors.terms}
                aria-describedby={errors.terms ? 'terms-error' : undefined}
                className="mt-0.5 size-[18px] shrink-0 accent-[var(--brand)]"
              />
              <span>
                {role === 'vendor' ? 'I certify that all store and location parameters are correct, and agree to the AeroDrop ' : 'I agree to the AeroDrop '}
                <Link to="/terms" target="_blank" rel="noopener" className="font-semibold text-brand-ink underline underline-offset-2">
                  Terms of Service
                </Link>{' '}
                and{' '}
                <Link to="/privacy" target="_blank" rel="noopener" className="font-semibold text-brand-ink underline underline-offset-2">
                  Privacy Policy
                </Link>
                .
              </span>
            </label>
            {errors.terms ? (
              <p id="terms-error" className="mt-1.5 pl-[30px] text-xs font-medium text-danger">
                {errors.terms}
              </p>
            ) : null}
          </div>
        ) : null}

        {formError ? <FormNote tone="error">{formError}</FormNote> : null}

        {role === 'vendor' && vendorStep === 2 ? (
          <div className="mt-1 grid grid-cols-[auto_minmax(0,1fr)] gap-3">
            <Button
              type="button"
              variant="outline"
              size="lg"
              onClick={() => {
                setVendorStep(1)
                setFormError(null)
              }}
            >
              Back
            </Button>
            <Button type="submit" size="lg" loading={busy} className="w-full">
              Submit application
            </Button>
          </div>
        ) : (
          <Button type="submit" size="lg" loading={busy} className="mt-1 w-full">
            {role === 'vendor' ? 'Continue to store details' : 'Create account'}
          </Button>
        )}

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
      </form>
    </AuthShell>
  )
}
