import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { api } from '@/data/api'
import { PageLoader } from '@/components/ui/loader'
import type { Profile, Role } from '@/types'

interface AuthState {
  user: Profile | null
  ready: boolean
  refresh: () => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

// Port of AuthState.sessionUnlocked: a password alone signs you in to
// Supabase, but the portal stays locked until the emailed code is verified
// (admins are exempt). Kept per tab, like a fresh app launch.
const UNLOCK_KEY = 'aerodrop-unlocked'
export function markUnlocked(id: string) {
  try {
    sessionStorage.setItem(UNLOCK_KEY, id)
  } catch {
    /* ignore */
  }
}
function isUnlocked(p: Profile) {
  if (p.role === 'admin') return true
  try {
    return sessionStorage.getItem(UNLOCK_KEY) === p.id
  } catch {
    return false
  }
}
function clearUnlocked() {
  try {
    sessionStorage.removeItem(UNLOCK_KEY)
  } catch {
    /* ignore */
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Profile | null>(null)
  const [ready, setReady] = useState(false)

  const refresh = useCallback(async () => {
    try {
      const id = await api.currentUserId()
      const profile = id ? await api.profile(id) : null
      setUser(profile && isUnlocked(profile) && profile.account_status === 'active' ? profile : null)
    } catch {
      setUser(null)
    } finally {
      setReady(true)
    }
  }, [])

  useEffect(() => {
    refresh()
    return api.onAuthChange(() => void refresh())
  }, [refresh])

  const signOut = useCallback(async () => {
    clearUnlocked()
    await api.signOut()
    setUser(null)
  }, [])

  return <AuthContext.Provider value={{ user, ready, refresh, signOut }}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}

/** Signed-in user, for screens behind RequireRole. */
export function useMe(): Profile {
  const { user } = useAuth()
  if (!user) throw new Error('useMe called outside a signed-in route')
  return user
}

/** The app router's landing rules, including complete_profile for accounts without a phone. */
export const homeFor = (u: Profile) =>
  u.role === 'admin' ? '/admin' : !u.phone_number?.trim() ? '/complete-profile' : u.role === 'vendor' && u.vendor_status === 'active' ? '/vendor' : u.vendor_status === 'pending' ? '/account-pending' : '/user'

/**
 * Port of the app router's redirect rules: signed-out visitors go to sign in,
 * and each role is bounced back to its own area.
 */
export function RequireRole({ role, children }: { role: Role; children: ReactNode }) {
  const { user, ready } = useAuth()
  const location = useLocation()
  if (!ready) return <PageLoader />
  if (!user) return <Navigate to="/sign-in" replace state={{ from: location.pathname }} />
  if (user.role !== 'admin' && !user.phone_number?.trim()) return <Navigate to="/complete-profile" replace />
  if (user.vendor_status === 'pending' && user.role !== 'admin') return <Navigate to="/account-pending" replace />
  const effective: Role = user.role === 'vendor' && user.vendor_status !== 'active' ? 'user' : user.role
  if (effective !== role) return <Navigate to={homeFor(user)} replace />
  return <>{children}</>
}
