import { Clock } from 'lucide-react'
import { Navigate, useNavigate } from 'react-router-dom'
import { homeFor, useAuth } from '@/auth/auth'
import { Button } from '@/components/ui/button'
import { PageLoader } from '@/components/ui/loader'
import { AuthShell } from './auth-shell'

export default function AccountPending() {
  const { user, ready, signOut, refresh } = useAuth()
  const navigate = useNavigate()
  if (!ready) return <PageLoader />
  if (!user) return <Navigate to="/sign-in" replace />
  if (user.vendor_status !== 'pending') return <Navigate to={homeFor(user)} replace />

  return (
    <AuthShell showBack={false} title="Application under review" subtitle={<>Thanks, {user.full_name.split(' ')[0]}. An administrator is reviewing <b className="text-ink">{user.business_name}</b>.</>}>
      <div className="flex gap-4 rounded-2xl bg-surface p-5 shadow-md">
        <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-warning-bg text-warning">
          <Clock aria-hidden className="size-5" />
        </span>
        <p className="text-sm text-ink-2">You will get a notification once your store is approved. After that, sign in again to open the vendor portal and add your products.</p>
      </div>
      <div className="mt-6 flex gap-3">
        <Button variant="secondary" onClick={() => refresh()}>
          Check again
        </Button>
        <Button
          variant="ghost"
          onClick={async () => {
            await signOut()
            navigate('/', { replace: true })
          }}
        >
          Sign out
        </Button>
      </div>
    </AuthShell>
  )
}
