import type { Profile } from '@/types'

/**
 * Migration 35: an account can be used before its email is verified, but it
 * cannot order. `undefined` means the column isn't there yet (migration not
 * applied), which counts as verified so nothing is blocked by mistake.
 */
export const needsEmailVerification = (p: Pick<Profile, 'role' | 'email_verified_at'> | null | undefined) =>
  !!p && p.role !== 'admin' && p.email_verified_at === null
