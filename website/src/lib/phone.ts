/**
 * normalizePhoneNumber from the app's auth_provider.dart: Philippine mobile
 * numbers in any of 09XXXXXXXXX, 9XXXXXXXXX, 639XXXXXXXXX or +639XXXXXXXXX,
 * stored as +639XXXXXXXXX. Returns null when the number is not valid.
 */
export function normalizePhone(raw: string): string | null {
  const clean = raw.replace(/[\s\-()]/g, '')
  if (/^09\d{9}$/.test(clean)) return `+63${clean.slice(1)}`
  if (/^9\d{9}$/.test(clean)) return `+63${clean}`
  if (/^639\d{9}$/.test(clean)) return `+${clean}`
  if (/^\+639\d{9}$/.test(clean)) return clean
  return null
}
