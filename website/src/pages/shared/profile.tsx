import { Camera, Cookie, FileText, KeyRound, LifeBuoy, Mail, Moon, ReceiptText, ShieldCheck, Store, Trash2 } from 'lucide-react'
import { useRef, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useAuth, useMe } from '@/auth/auth'
import { EmailVerificationStatus } from '@/components/verify-email'
import { Button } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/ui/dialog'
import { Avatar, Badge, Card, CardHeader, Field, Input, Select, Switch, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { openCookieSettings } from '@/lib/consent'
import { VENDOR_CATEGORIES } from '@/lib/constants'
import { formatDate } from '@/lib/format'
import { isHub } from '@/lib/flight'
import { errorMessage, useQuery } from '@/lib/store'
import { setTheme, useTheme } from '@/lib/theme'

export default function Profile() {
  const me = useMe()
  const { refresh } = useAuth()
  const theme = useTheme()
  const locations = useQuery(() => api.locations())
  const isVendor = me.role === 'vendor'
  const [form, setForm] = useState({
    full_name: me.full_name,
    phone_number: me.phone_number ?? '',
    campus_location_id: me.campus_location_id ?? '',
    business_name: me.business_name ?? '',
    business_category: me.business_category ?? VENDOR_CATEGORIES[0]!,
    business_description: me.business_description ?? '',
  })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [pw, setPw] = useState({ current: '', next: '', confirm: '' })
  const [pwError, setPwError] = useState<string | null>(null)
  const [pwBusy, setPwBusy] = useState(false)

  const set = (k: keyof typeof form) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }))
  const locs = (locations.data ?? []).filter((l) => !isHub(l))

  async function save(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (form.full_name.trim().length < 2) return setError('Enter your full name.')
    if (isVendor && form.business_name.trim().length < 2) return setError('Enter your store name.')
    setSaving(true)
    try {
      await api.updateProfile(me.id, {
        full_name: form.full_name.trim(),
        phone_number: form.phone_number.trim() || null,
        campus_location_id: form.campus_location_id || null,
        ...(isVendor ? { business_name: form.business_name.trim(), business_category: form.business_category, business_description: form.business_description.trim() || null } : {}),
      })
      await refresh()
      toast('Profile saved.')
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  async function changePassword(e: FormEvent) {
    e.preventDefault()
    setPwError(null)
    if (!pw.current) return setPwError('Current password is required')
    if (pw.next.length < 6) return setPwError('Password must be at least 6 characters')
    if (pw.next !== pw.confirm) return setPwError('Passwords do not match')
    setPwBusy(true)
    try {
      await api.changePassword(pw.current, pw.next)
      setPw({ current: '', next: '', confirm: '' })
      toast('Password updated successfully!')
    } catch (err) {
      setPwError(errorMessage(err))
    } finally {
      setPwBusy(false)
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[320px_minmax(0,1fr)]">
      <div className="flex flex-col gap-6">
        <Card className="flex flex-col items-center p-6 text-center">
          <PhotoPicker vendor={isVendor} />
          <h2 className="mt-4 font-display text-xl font-bold text-ink">{isVendor ? me.business_name : me.full_name}</h2>
          <p className="text-sm text-ink-3">{me.email}</p>
          <div className="mt-3 flex gap-2">
            <Badge tone="info">{isVendor ? 'Vendor' : 'Customer'}</Badge>
            {isVendor && me.business_category ? <Badge>{me.business_category}</Badge> : null}
          </div>
          <div className="mt-4">
            <EmailVerificationStatus me={me} />
          </div>
          <p className="mt-4 text-xs text-ink-3">Member since {formatDate(me.created_at)}</p>
        </Card>
        <Card className="p-2">
          {(isVendor
            ? [
                { to: '/vendor/orders', icon: ReceiptText, label: 'Incoming orders' },
                { to: '/vendor/products', icon: Store, label: 'Products' },
                { to: '/vendor/help', icon: LifeBuoy, label: 'Help and support' },
                { to: '/terms', icon: FileText, label: 'Terms and conditions' },
                { to: '/privacy', icon: ShieldCheck, label: 'Privacy policy' },
              ]
            : [
                { to: '/user/orders', icon: ReceiptText, label: 'Order history' },
                { to: '/user/help', icon: LifeBuoy, label: 'Help and support' },
                { to: '/terms', icon: FileText, label: 'Terms and conditions' },
                { to: '/privacy', icon: ShieldCheck, label: 'Privacy policy' },
              ]
          ).map((l) => (
            <Link key={l.to} to={l.to} className="flex h-12 items-center gap-3 rounded-xl px-3 text-sm font-medium text-ink-2 hover:bg-sunken hover:text-ink">
              <l.icon aria-hidden className="size-[18px]" /> {l.label}
            </Link>
          ))}
          <div className="flex h-12 items-center gap-3 px-3 text-sm font-medium text-ink-2">
            <Moon aria-hidden className="size-[18px]" />
            <span className="flex-1">Dark theme</span>
            <Switch label="Dark theme" checked={theme === 'dark'} onChange={(v) => setTheme(v ? 'dark' : 'light')} />
          </div>
          <button type="button" onClick={openCookieSettings} className="flex h-12 w-full items-center gap-3 rounded-xl px-3 text-left text-sm font-medium text-ink-2 hover:bg-sunken hover:text-ink">
            <Cookie aria-hidden className="size-[18px]" /> Cookie settings
          </button>
        </Card>
      </div>

      <div className="flex flex-col gap-6">
        <Card>
          <CardHeader title={isVendor ? 'Vendor Information' : 'Edit profile details'} description={isVendor ? 'Shown to customers on your store page.' : 'Name, phone and default drop-off.'} />
          <form onSubmit={save} noValidate className="grid gap-4 p-5 sm:grid-cols-2">
            <Field label={isVendor ? 'Owner' : 'Full name'}>{(p) => <Input {...p} autoComplete="name" value={form.full_name} onChange={set('full_name')} />}</Field>
            <Field label="Phone">{(p) => <Input {...p} type="tel" autoComplete="tel" value={form.phone_number} onChange={set('phone_number')} />}</Field>
            <Field label="Email" hint="Change it in Account security below.">{(p) => <Input {...p} value={me.email} disabled />}</Field>
            <Field label={isVendor ? 'Stall location' : 'Default drop-off'}>
              {(p) => (
                <Select {...p} value={form.campus_location_id} onChange={set('campus_location_id')}>
                  <option value="">Not set</option>
                  {locs.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
                </Select>
              )}
            </Field>
            {isVendor ? (
              <>
                <Field label="Store name">{(p) => <Input {...p} value={form.business_name} onChange={set('business_name')} />}</Field>
                <Field label="Category">
                  {(p) => (
                    <Select {...p} value={form.business_category} onChange={set('business_category')}>
                      {[...new Set([...VENDOR_CATEGORIES, form.business_category])].map((c) => <option key={c}>{c}</option>)}
                    </Select>
                  )}
                </Field>
                <Field label="Description" className="sm:col-span-2">{(p) => <Textarea {...p} value={form.business_description} onChange={set('business_description')} maxLength={300} />}</Field>
              </>
            ) : null}
            {error ? <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 text-sm font-medium text-danger sm:col-span-2">{error}</p> : null}
            <div className="sm:col-span-2">
              <Button type="submit" loading={saving}>Save changes</Button>
            </div>
          </form>
        </Card>

        <Card>
          <CardHeader title="Change password" description="Confirm your current password first." />
          <form onSubmit={changePassword} noValidate className="grid gap-4 p-5 sm:grid-cols-2">
            <Field label="Current password" className="sm:col-span-2">{(p) => <Input {...p} type="password" autoComplete="current-password" value={pw.current} onChange={(e) => setPw({ ...pw, current: e.target.value })} />}</Field>
            <Field label="New password" hint="At least 6 characters.">{(p) => <Input {...p} type="password" autoComplete="new-password" value={pw.next} onChange={(e) => setPw({ ...pw, next: e.target.value })} />}</Field>
            <Field label="Confirm new password" error={pwError}>{(p) => <Input {...p} type="password" autoComplete="new-password" value={pw.confirm} onChange={(e) => setPw({ ...pw, confirm: e.target.value })} />}</Field>
            <div className="sm:col-span-2">
              <Button type="submit" variant="secondary" loading={pwBusy} icon={<KeyRound aria-hidden className="size-4" />}>Update password</Button>
            </div>
          </form>
        </Card>

        <ChangeEmail />
      </div>
    </div>
  )
}

/** edit_profile_screen.dart: pick, upload or remove the avatar (or the store logo for vendors). */
function PhotoPicker({ vendor }: { vendor: boolean }) {
  const me = useMe()
  const { refresh } = useAuth()
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  const src = vendor ? me.business_logo_url : me.avatar_url
  const noun = vendor ? 'store logo' : 'profile picture'

  async function run(fn: () => Promise<unknown>, ok: string) {
    setBusy(true)
    try {
      await fn()
      await refresh()
      toast(ok)
    } catch (e) {
      toast(errorMessage(e) || `Failed to upload ${noun}.`, 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-col items-center">
      <div className="relative">
        <Avatar name={vendor ? me.business_name : me.full_name} src={src} size={88} className={vendor ? 'rounded-2xl' : ''} />
        <button
          type="button"
          disabled={busy}
          onClick={() => input.current?.click()}
          aria-label={`Change ${noun}`}
          className="absolute -right-1 -bottom-1 grid size-9 place-items-center rounded-full bg-brand text-on-brand shadow-md ring-4 ring-surface transition-transform duration-150 active:scale-[0.96] disabled:opacity-60"
        >
          <Camera aria-hidden className={busy ? 'size-4 animate-pulse' : 'size-4'} />
        </button>
      </div>
      <input
        ref={input}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        tabIndex={-1}
        aria-hidden
        onChange={(e) => {
          const file = e.target.files?.[0]
          e.target.value = ''
          if (file) run(() => (vendor ? api.uploadStoreLogo(file) : api.uploadAvatar(file)), vendor ? 'Store logo updated.' : 'Profile picture updated.')
        }}
      />
      {src ? (
        <ConfirmDialog
          trigger={<button type="button" className="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-ink-3 hover:text-danger"><Trash2 aria-hidden className="size-3.5" /> Remove {noun}</button>}
          title={vendor ? 'Remove Logo' : 'Remove Avatar'}
          body={`Are you sure you want to remove your ${noun}?`}
          confirmLabel="Remove"
          onConfirm={() => run(() => (vendor ? api.removeStoreLogo() : api.updateProfile(me.id, { avatar_url: null })), vendor ? 'Store logo removed.' : 'Profile picture removed.')}
        />
      ) : null}
      <p className="mt-2 text-xs text-ink-3">JPEG, PNG or WebP, up to 5 MB.</p>
    </div>
  )
}

/** settings_page.dart "Change email address": Supabase sends links to both addresses. */
function ChangeEmail() {
  const [email, setEmail] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  return (
    <Card>
      <CardHeader title="Change email address" description="You get a confirmation link at your current and your new address. Verify both to finish the change." />
      <form
        noValidate
        className="flex flex-col gap-4 p-5 sm:flex-row sm:items-start"
        onSubmit={async (e) => {
          e.preventDefault()
          const next = email.trim().toLowerCase()
          setError(null)
          if (!next) return setError('Email is required')
          if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(next)) return setError('Enter a valid email address')
          setBusy(true)
          try {
            await api.changeEmail(next)
            setEmail('')
            toast(`Confirmation link sent to ${next} and your current email. Verify both to complete the change.`)
          } catch (err) {
            setError(`Could not update your email: ${errorMessage(err)}`)
          } finally {
            setBusy(false)
          }
        }}
      >
        <Field label="New email address" error={error} className="flex-1">{(p) => <Input {...p} type="email" autoComplete="email" placeholder="you@example.com" value={email} onChange={(e) => setEmail(e.target.value)} />}</Field>
        <Button type="submit" variant="secondary" loading={busy} icon={<Mail aria-hidden className="size-4" />} className="sm:mt-7">Send confirmation links</Button>
      </form>
    </Card>
  )
}
