import { CircleAlert } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { homeFor, markUnlocked, useAuth } from '@/auth/auth'
import { ButtonLink } from '@/components/ui/button'
import { Spinner } from '@/components/ui/loader'
import { api } from '@/data/api'
import { errorMessage } from '@/lib/store'
import { AuthShell } from './auth-shell'

/**
 * Where Google sends the browser back to (the web version of the app's OAuth
 * deep link). Finishes the session like _handleOAuthSignInSuccess: wait for
 * the users row, refuse suspended, deleted and admin accounts, then unlock
 * the session (Google already verified the email, so no code is sent).
 */
export default function AuthCallback() {
  const navigate = useNavigate()
  const { refresh } = useAuth()
  const [error, setError] = useState<string | null>(() => {
    const params = new URLSearchParams(window.location.search + window.location.hash.replace(/^#/, '&'))
    const denied = params.get('error_description') ?? params.get('error')
    return denied ? denied.replace(/\+/g, ' ') : null
  })
  const started = useRef(false)

  useEffect(() => {
    if (started.current) return
    started.current = true
    if (error) return
    api
      .completeGoogleSignIn()
      .then(async (profile) => {
        markUnlocked(profile.id)
        await refresh()
        navigate(homeFor(profile), { replace: true })
      })
      .catch((e) => setError(errorMessage(e)))
  }, [error, navigate, refresh])

  return (
    <AuthShell showBack={false} title={error ? 'Google sign-in failed' : 'Signing you in'} subtitle={error ? undefined : 'Finishing your Google sign-in…'}>
      {error ? (
        <div className="flex flex-col gap-5">
          <p role="alert" className="flex gap-2 rounded-xl bg-danger-bg px-4 py-3 text-sm font-medium text-danger">
            <CircleAlert aria-hidden className="mt-0.5 size-4 shrink-0" /> {error}
          </p>
          <ButtonLink to="/sign-in" size="lg">Back to sign in</ButtonLink>
        </div>
      ) : (
        <div className="flex justify-center py-6" aria-live="polite">
          <Spinner size={24} />
        </div>
      )}
    </AuthShell>
  )
}
