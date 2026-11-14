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

/**
 * The 10 digits after +63 (a PH mobile starts with 9), from whatever was
 * typed or pasted: "0917 123 4567", "+63 917…", "63917…" or "917…". Anything
 * past 10 digits is dropped, so the field can't hold a longer number.
 */
export function phLocalDigits(raw: string): string {
  let d = raw.replace(/\D/g, '')
  if (d.startsWith('63') && d.length > 10) d = d.slice(2)
  if (d.startsWith('0')) d = d.slice(1)
  return d.slice(0, 10)
}

/** "9171234567" → "917 123 4567", as typed. */
export function formatPhLocal(digits: string): string {
  const d = digits.slice(0, 10)
  return [d.slice(0, 3), d.slice(3, 6), d.slice(6)].filter(Boolean).join(' ')
}

/** A complete PH mobile number: 9 then nine more digits. */
export const isPhMobile = (raw: string) => /^9\d{9}$/.test(phLocalDigits(raw))

/** Stored form (+639XXXXXXXXX), or null when it isn't a complete PH mobile number. */
export const toPhE164 = (raw: string) => (isPhMobile(raw) ? `+63${phLocalDigits(raw)}` : null)

export const PH_PHONE_ERROR = 'Enter a Philippine mobile number: 10 digits starting with 9, like 917 123 4567.'
