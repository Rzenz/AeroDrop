import * as Alert from '@radix-ui/react-alert-dialog'
import { CircleAlert, LogOut } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth, useMe } from '@/auth/auth'
import { Button } from '@/components/ui/button'
import { api } from '@/data/api'
import { startFlightSimulator } from '@/lib/flight-sim'
import { invalidateSoon } from '@/lib/store'
import type { AccountStatus, Role } from '@/types'

/**
 * The background work the app's shells and providers do while signed in:
 * - DeliveryNotifier's flight simulator (every 3s)
 * - the realtime channels on orders, deliveries, drones, weather, chat,
 *   notifications and telemetry
 * - UserShell's account-status check (every 10s, customers and vendors):
 *   a suspended or deleted account is signed out
 */
export function BackendSync({ role }: { role: Role }) {
  const me = useMe()
  const { signOut } = useAuth()
  const navigate = useNavigate()
  const [blocked, setBlocked] = useState<AccountStatus | null>(null)

  useEffect(() => {
    const sim = startFlightSimulator(api, role, () => invalidateSoon())
    const unsubscribe = api.subscribeChanges({ userId: me.id, role }, () => invalidateSoon())
    return () => {
      sim.stop()
      unsubscribe()
    }
  }, [me.id, role])

  useEffect(() => {
    if (role === 'admin') return // the admin side stays usable, as in the app
    let alive = true
    const check = () =>
      api
        .accountStatus(me.id)
        .then((s) => alive && (s === 'suspended' || s === 'deleted') && setBlocked(s))
        .catch(() => undefined)
    check()
    const id = setInterval(check, 10_000)
    const onVisible = () => document.visibilityState === 'visible' && check()
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      alive = false
      clearInterval(id)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [me.id, role])

  return (
    <Alert.Root open={!!blocked}>
      <Alert.Portal>
        <Alert.Overlay className="fixed inset-0 z-40 bg-black/60" />
        <Alert.Content className="fixed top-1/2 left-1/2 z-50 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-2xl bg-surface p-6 shadow-lg focus:outline-none">
          <Alert.Title className="flex items-center gap-2 font-display text-lg font-bold text-ink">
            <CircleAlert aria-hidden className="size-6 text-danger" />
            {blocked === 'suspended' ? 'Account Suspended' : 'Account Deleted'}
          </Alert.Title>
          <Alert.Description className="mt-2 text-sm text-ink-2">
            {blocked === 'suspended' ? 'Your account has been suspended.' : 'Your account has been deleted.'} Please contact the administrator.
          </Alert.Description>
          <div className="mt-6 flex justify-end">
            <Alert.Action asChild>
              <Button
                variant="danger"
                icon={<LogOut aria-hidden className="size-4" />}
                onClick={async () => {
                  await signOut()
                  navigate('/sign-in', { replace: true })
                }}
              >
                Log Out
              </Button>
            </Alert.Action>
          </div>
        </Alert.Content>
      </Alert.Portal>
    </Alert.Root>
  )
}
