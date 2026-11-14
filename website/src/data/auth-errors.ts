/**
 * AuthNotifier.login: a password sign-in on an unverified email. A fresh
 * sign-up code has been sent, so the page asks for it instead of failing.
 */
/** check-email turned the address down; `suggestion` is the likely intended address for a typo. */
export class EmailRejectedError extends Error {
  readonly suggestion?: string
  constructor(message: string, suggestion?: string) {
    super(message)
    this.name = 'EmailRejectedError'
    this.suggestion = suggestion
  }
}

export class EmailNotVerifiedError extends Error {
  constructor(message = "Your email isn't verified yet. We sent you a new code.") {
    super(message)
    this.name = 'EmailNotVerifiedError'
  }
}

type AuthErrorLike = { message?: string; code?: string; status?: number } | null | undefined

const isRateLimit = (code: string, msg: string) =>
  code === 'over_email_send_rate_limit' || code === 'rate_limit_exceeded' || msg.includes('rate limit') || msg.includes('too many requests') || msg.includes('security purposes')

export const isAlreadyRegistered = (e: AuthErrorLike) => {
  const code = e?.code?.toLowerCase() ?? ''
  const msg = e?.message?.toLowerCase() ?? ''
  return code === 'user_already_exists' || code === 'email_exists' || msg.includes('already registered') || msg.includes('already exists')
}

/**
 * Supabase accepted the request but could not email the code. With the
 * built-in sender this is "Email address not authorized" for anyone outside
 * the project's team; with a broken custom SMTP it is "Error sending ...".
 */
export const isEmailDeliveryFailure = (e: AuthErrorLike) => {
  const code = e?.code?.toLowerCase() ?? ''
  const msg = e?.message?.toLowerCase() ?? ''
  return code === 'email_address_not_authorized' || msg.includes('not authorized') || msg.includes('error sending') || code === 'unexpected_failure' && msg.includes('email')
}

export const EMAIL_NOT_SENT =
  "We couldn't email your code. AeroDrop's email service isn't accepting this address yet. Please try again later or contact the AeroDrop team."

export const isRateLimited = (e: AuthErrorLike) => isRateLimit(e?.code?.toLowerCase() ?? '', e?.message?.toLowerCase() ?? '')

/** formatAuthErrorMessage (auth_provider.dart): Supabase's auth errors in the app's words. */
export function authMessage(e: AuthErrorLike): string {
  const code = e?.code?.toLowerCase() ?? ''
  const raw = e?.message ?? ''
  const msg = raw.toLowerCase()
  if (msg.includes('failed to fetch') || msg.includes('network') || msg.includes('load failed')) return 'Network connection failed. Please check your internet connection and try again.'
  if (code === 'email_address_invalid') return 'Please enter a valid email address.'
  // Migration 34's trigger refused a throwaway or misspelled email domain.
  if (msg.includes('database error saving new user')) return "This email address can't be used to register. Use your personal or school email."
  if (isEmailDeliveryFailure(e)) return EMAIL_NOT_SENT
  if (isRateLimit(code, msg)) return 'Too many attempts. Please wait a few minutes before trying again.'
  if (isAlreadyRegistered(e)) return 'This email may already be registered. Try signing in or use a different email.'
  if (code === 'email_provider_disabled' || code === 'signup_disabled') return 'Registration is currently unavailable.'
  if (code === 'weak_password') return raw
  if (code === 'otp_expired' || msg.includes('token has expired or is invalid')) return 'That code is incorrect or has expired. Check your email or request a new code.'
  if (code === 'invalid_credentials' || msg.includes('invalid login credentials')) return 'Incorrect email or password.'
  if (msg.includes('invalid otp') || msg.includes('token is invalid')) return 'That code is incorrect. Check your email and try again.'
  return raw || 'Something went wrong. Please try again.'
}

/** `ok()` for auth calls: throws the app's wording instead of Supabase's. */
export function authOk<R extends { error: AuthErrorLike }>(res: R): R {
  if (res.error) throw new Error(authMessage(res.error))
  return res
}
