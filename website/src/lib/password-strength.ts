/**
 * Password strength for the sign-up meter. Advisory: the only hard rule is
 * the app's 6-character minimum, so an account made on either client follows
 * the same rule. The meter nudges people toward something better.
 */

export type StrengthLevel = 0 | 1 | 2 | 3 | 4

export interface PasswordTip {
  id: 'length' | 'case' | 'number' | 'symbol'
  label: string
  met: boolean
}

export interface PasswordStrength {
  /** 0 when empty, then 1 Weak … 4 Strong. */
  level: StrengthLevel
  label: '' | 'Too short' | 'Weak' | 'Fair' | 'Good' | 'Strong'
  tips: PasswordTip[]
  /** A specific problem worth naming, such as a well-known password. */
  warning?: string
}

// Passwords that appear at the top of every breach list, plus local ones.
const COMMON = new Set([
  '123456', '1234567', '12345678', '123456789', '1234567890', '111111', '000000', '123123', '654321', '666666', '888888',
  'password', 'password1', 'password123', 'passw0rd', 'qwerty', 'qwerty123', 'qwertyuiop', 'abc123', 'abcdef', 'asdfgh',
  'iloveyou', 'letmein', 'welcome', 'admin', 'admin123', 'monkey', 'dragon', 'sunshine', 'princess', 'football',
  'aerodrop', 'aerodrop123', 'uclm', 'uclm123', 'cebu', 'mandaue', 'mahalkita', 'iloveu',
])

const RUNS = ['01234567890', 'abcdefghijklmnopqrstuvwxyz', 'qwertyuiop', 'asdfghjkl', 'zxcvbnm']

/** The whole password is a straight run on the keyboard or alphabet, either way. */
function isSequence(lower: string) {
  if (lower.length < 4) return false
  return RUNS.some((run) => run.includes(lower) || [...run].reverse().join('').includes(lower))
}

export function passwordStrength(password: string, personal: string[] = []): PasswordStrength {
  const tips: PasswordTip[] = [
    { id: 'length', label: 'At least 8 characters', met: password.length >= 8 },
    { id: 'case', label: 'Upper and lower case letters', met: /[a-z]/.test(password) && /[A-Z]/.test(password) },
    { id: 'number', label: 'At least one number', met: /\d/.test(password) },
    { id: 'symbol', label: 'A symbol, like ! # or @', met: /[^A-Za-z0-9]/.test(password) },
  ]
  if (!password) return { level: 0, label: '', tips }

  const lower = password.toLowerCase()
  let warning: string | undefined
  if (COMMON.has(lower)) warning = 'This is one of the most common passwords. Pick something only you would know.'
  else if (/^(.)\1+$/.test(password)) warning = 'Avoid repeating the same character.'
  else if (isSequence(lower)) warning = 'Avoid simple sequences like 1234 or abcd.'
  else {
    const hit = personal
      .map((p) => p.trim().toLowerCase())
      .flatMap((p) => p.split(/[\s@._-]+/))
      .find((part) => part.length >= 3 && lower.includes(part))
    if (hit) warning = "Don't use your name or email in your password."
  }

  if (password.length < 6) return { level: 1, label: 'Too short', tips, warning: warning ?? 'Use at least 6 characters.' }

  let score = tips.filter((t) => t.met).length
  if (password.length >= 12) score += 1
  let level = Math.min(4, Math.max(1, score)) as StrengthLevel
  if (warning) level = 1
  // Long passphrases are strong even without symbols.
  if (!warning && password.length >= 16) level = 4

  const label = (['', 'Weak', 'Fair', 'Good', 'Strong'] as const)[level]
  return { level, label, tips, warning }
}
