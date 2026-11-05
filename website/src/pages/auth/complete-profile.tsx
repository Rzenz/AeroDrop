import { Phone } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { homeFor, useAuth } from '@/auth/auth'
import { Avatar, Field, Input } from '@/components/ui/primitives'
import { Button } from '@/components/ui/button'
import { PageLoader } from '@/components/ui/loader'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { normalizePhone } from '@/lib/phone'
import { errorMessage } from '@/lib/store'
import { AuthShell } from './auth-shell'

/**
 * complete_profile_screen.dart: accounts without a mobile number (Google
 * sign-ups) add one before using AeroDrop, so dispatch can send arrival
 * notifications. The router sends non-admins here until it is set.
 */
export default function CompleteProfile() {
  const { user, ready, refresh, signOut } = useAuth()
  const navigate = useNavigate()
  const [phone, setPhone] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  if (!ready) return <PageLoader />
  if (!user) return <Navigate to="/sign-in" replace />
  if (user.role === 'admin' || user.phone_number?.trim()) return <Navigate to={homeFor(user)} replace />

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!phone.trim()) return setError('Please enter your mobile number')
    const normalized = normalizePhone(phone)
    if (!normalized) return setError('Please enter a valid format (e.g. 0917 123 4567)')
    setBusy(true)
    try {
      await api.updateProfile(user!.id, { full_name: user!.full_name || 'Customer', phone_number: normalized })
      await refresh()
      toast('Profile completed successfully! Welcome to AeroDrop.')
      navigate(homeFor({ ...user!, phone_number: normalized }), { replace: true })
    } catch (err) {
      setError(errorMessage(err) || 'Failed to update phone number.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthShell showBack={false} title="Complete your profile" subtitle="Add your mobile number so our drone dispatch system can send arrival notifications.">
      <div className="mb-6 flex items-center gap-3 rounded-2xl bg-surface p-4 shadow-sm">
        <Avatar name={user.full_name} src={user.avatar_url} size={44} />
        <div className="min-w-0">
          <p className="truncate font-semibold text-ink">{user.full_name || 'Google User'}</p>
          <p className="truncate text-sm text-ink-3">{user.email}</p>
        </div>
      </div>
      <form onSubmit={submit} noValidate className="flex flex-col gap-5">
        <Field label="Mobile number" error={error} hint="Format: 09XX XXX XXXX or +63 9XX XXX XXXX">
          {(p) => (
            <div className="relative">
              <Phone aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-ink-3" />
              <Input {...p} type="tel" inputMode="tel" autoComplete="tel" placeholder="0917 123 4567" value={phone} onChange={(e) => setPhone(e.target.value)} className="pl-10" />
            </div>
          )}
        </Field>
        <Button type="submit" size="lg" loading={busy}>Save and continue</Button>
        <button
          type="button"
          className="self-center text-sm font-semibold text-ink-2 hover:text-ink"
          onClick={async () => {
            await signOut()
            navigate('/sign-in', { replace: true })
          }}
        >
          Sign out and use another account
        </button>
      </form>
    </AuthShell>
  )
}
