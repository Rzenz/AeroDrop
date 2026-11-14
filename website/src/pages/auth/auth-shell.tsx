import { AlertTriangle, ArrowLeft, Check, Eye, EyeOff, Moon, ShieldCheck, Smartphone, Sun } from 'lucide-react'
import { motion } from 'motion/react'
import { useRef, useState, type InputHTMLAttributes, type ReactNode } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Logo } from '@/components/brand'
import { IconButton } from '@/components/ui/button'
import { passwordStrength } from '@/lib/password-strength'
import { setTheme, useTheme } from '@/lib/theme'
import { cn } from '@/lib/utils'

/**
 * Back control for the auth screens. A real button with a visible label and a
 * 44px target; the arrow nudges left on hover to show direction.
 */
export function BackButton({ onClick, label = 'Back' }: { onClick: () => void; label?: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="group -ml-2.5 inline-flex h-10 w-fit items-center gap-1.5 rounded-xl ps-2 pe-3 text-sm font-semibold text-ink-2 transition-[background-color,color,scale] duration-150 ease-out hover:bg-sunken hover:text-ink active:scale-[0.96]"
    >
      <ArrowLeft aria-hidden strokeWidth={2.25} className="size-4 transition-transform duration-150 ease-out group-hover:-translate-x-0.5" />
      {label}
    </button>
  )
}

/** Previous page when there is one in this tab, otherwise the landing page. */
function useGoBack() {
  const navigate = useNavigate()
  return () => {
    const idx = (window.history.state as { idx?: number } | null)?.idx ?? 0
    if (idx > 0) navigate(-1)
    else navigate('/')
  }
}

/**
 * The quiet scenery behind the card: the UCLM campus fading into the page at
 * the top, a faint dot grid, and one soft halo of the brand sky behind the
 * card. Nothing moves, so nothing costs a frame.
 */
function Backdrop() {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 -z-10 overflow-hidden">
      <img
        src="/img/uclm-campus.jpg"
        alt=""
        className="no-outline absolute inset-x-0 top-0 h-[58vh] w-full object-cover opacity-[0.10] grayscale [mask-image:linear-gradient(to_bottom,black_10%,transparent)] dark:opacity-[0.22]"
      />
      <div className="absolute inset-0 [background-image:radial-gradient(var(--line)_1px,transparent_1px)] [background-size:24px_24px] [mask-image:radial-gradient(ellipse_70%_60%_at_50%_40%,black,transparent)]" />
      <div className="absolute top-[18%] left-1/2 size-[560px] -translate-x-1/2 rounded-full bg-[var(--sky)] opacity-[0.10] blur-[110px] dark:opacity-[0.14]" />
    </div>
  )
}

function ThemeSwitch() {
  const theme = useTheme()
  return (
    <IconButton label={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      {theme === 'dark' ? <Sun aria-hidden className="size-5" /> : <Moon aria-hidden className="size-5" />}
    </IconButton>
  )
}

const YEAR = new Date().getFullYear()

export function AuthShell({
  title,
  subtitle,
  children,
  footer,
  onBack,
  backLabel,
  showBack = true,
  wide = false,
}: {
  title: string
  subtitle?: ReactNode
  children: ReactNode
  footer?: ReactNode
  /** Step-level back (e.g. code entry → form). Defaults to leaving the page. */
  onBack?: () => void
  backLabel?: string
  showBack?: boolean
  /** Room for two fields side by side (sign-up). */
  wide?: boolean
}) {
  const goBack = useGoBack()
  return (
    <div className="relative isolate flex min-h-dvh flex-col bg-bg">
      <Backdrop />
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-4 pt-[max(1rem,env(safe-area-inset-top))] sm:px-6">
        <Logo />
        <ThemeSwitch />
      </header>

      <main className="flex flex-1 flex-col items-center justify-center px-4 py-10 sm:py-14">
        <motion.section
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, ease: 'easeOut' }}
          aria-labelledby="auth-title"
          className={cn('w-full rounded-[28px] bg-surface p-6 shadow-[var(--shadow-lg)] sm:p-10', wide ? 'max-w-[600px]' : 'max-w-[448px]')}
        >
          <div className="h-10">{showBack ? <BackButton onClick={onBack ?? goBack} label={backLabel} /> : null}</div>
          <div className="flex flex-col items-center text-center">
            <img src="/img/brand-mark.png" alt="" width={56} height={56} className="size-14 rounded-2xl shadow-[var(--shadow-md)]" />
            <h1 id="auth-title" className="mt-5 font-display text-[28px] leading-tight font-extrabold text-balance text-ink sm:text-[32px]">
              {title}
            </h1>
            {subtitle ? <p className="mt-2 max-w-sm text-[15px] text-pretty text-ink-2">{subtitle}</p> : null}
          </div>
          <div className="mt-8">{children}</div>
          {footer ? <div className="mt-8 border-t border-line pt-6 text-center text-sm text-ink-2">{footer}</div> : null}
        </motion.section>

        <ul className="mt-8 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-xs text-ink-3">
          <li className="flex items-center gap-1.5">
            <ShieldCheck aria-hidden className="size-4 text-brand" />
            Emailed code at every sign-in
          </li>
          <li className="flex items-center gap-1.5">
            <Smartphone aria-hidden className="size-4 text-brand" />
            One account for the app and the web
          </li>
        </ul>
      </main>

      <footer className="flex items-center justify-center gap-4 px-4 pb-[max(1.25rem,env(safe-area-inset-bottom))] text-xs text-ink-3">
        <span>© {YEAR} AeroDrop</span>
        <Link to="/terms" className="hover:text-ink">
          Terms
        </Link>
        <Link to="/privacy" className="hover:text-ink">
          Privacy
        </Link>
      </footer>
    </div>
  )
}

/** The auth screens' taller input, with a leading icon. */
export function AuthInput({ icon, className, ...props }: InputHTMLAttributes<HTMLInputElement> & { icon?: ReactNode }) {
  return (
    <div className="relative">
      {icon ? <span className="pointer-events-none absolute top-1/2 left-3.5 grid size-5 -translate-y-1/2 place-items-center text-ink-3 [&>svg]:size-[18px]">{icon}</span> : null}
      <input
        className={cn(
          'h-12 w-full rounded-xl bg-sunken px-4 text-[15px] text-ink placeholder:text-ink-3 shadow-[inset_0_0_0_1px_var(--line)] transition-shadow duration-150 ease-out',
          'focus:shadow-[inset_0_0_0_2px_var(--brand)] focus:outline-none aria-[invalid=true]:shadow-[inset_0_0_0_2px_var(--danger)] disabled:opacity-60',
          icon && 'pl-11',
          className,
        )}
        {...props}
      />
    </div>
  )
}

/** Password field with a show/hide toggle. */
export function PasswordInput({ icon, ...props }: Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> & { icon?: ReactNode }) {
  const [show, setShow] = useState(false)
  return (
    <div className="relative">
      <AuthInput {...props} icon={icon} type={show ? 'text' : 'password'} className="pr-12" />
      <button
        type="button"
        onClick={() => setShow((v) => !v)}
        aria-label={show ? 'Hide password' : 'Show password'}
        aria-pressed={show}
        className="absolute top-1/2 right-1.5 grid size-9 -translate-y-1/2 place-items-center rounded-lg text-ink-3 transition-colors duration-150 hover:bg-surface hover:text-ink"
      >
        {show ? <EyeOff aria-hidden className="size-[18px]" /> : <Eye aria-hidden className="size-[18px]" />}
      </button>
    </div>
  )
}

const LEVEL_TONE = ['', 'var(--danger)', 'var(--warning)', 'var(--sky)', 'var(--success)'] as const
const LEVEL_TEXT = ['', 'text-danger', 'text-warning', 'text-brand-ink', 'text-success'] as const

/**
 * A four-part strength bar and the tips that would raise it. Shown once the
 * person starts typing; `personal` is their name and email, which a password
 * should not contain.
 */
export function PasswordStrengthMeter({ password, personal = [], id }: { password: string; personal?: string[]; id?: string }) {
  const s = passwordStrength(password, personal)
  if (!password) return null
  return (
    <div id={id} className="rounded-xl bg-surface-2 p-3.5 shadow-[inset_0_0_0_1px_var(--line)]">
      <div className="flex items-center gap-3">
        <div
          role="meter"
          aria-label="Password strength"
          aria-valuemin={0}
          aria-valuemax={4}
          aria-valuenow={s.level}
          aria-valuetext={s.label}
          className="grid flex-1 grid-cols-4 gap-1.5"
        >
          {[1, 2, 3, 4].map((i) => (
            <span
              key={i}
              className="h-1.5 rounded-full bg-line transition-[background-color] duration-150 ease-out"
              style={i <= s.level ? { backgroundColor: LEVEL_TONE[s.level] } : undefined}
            />
          ))}
        </div>
        <span aria-live="polite" className={cn('w-16 text-right text-xs font-semibold', LEVEL_TEXT[s.level])}>
          {s.label}
        </span>
      </div>
      {s.warning ? (
        <p className="mt-2.5 flex items-start gap-1.5 text-xs font-medium text-warning">
          <AlertTriangle aria-hidden className="mt-px size-3.5 shrink-0" />
          {s.warning}
        </p>
      ) : null}
      {s.level < 4 ? (
        <ul aria-label="Tips for a stronger password" className="mt-2.5 grid gap-x-4 gap-y-1.5 text-xs sm:grid-cols-2">
          {s.tips.map((t) => (
            <li key={t.id} className={cn('flex items-center gap-1.5', t.met ? 'text-ink-2' : 'text-ink-3')}>
              {t.met ? (
                <Check aria-hidden strokeWidth={2.5} className="size-3.5 shrink-0 text-success" />
              ) : (
                <span aria-hidden className="grid size-3.5 shrink-0 place-items-center">
                  <span className="size-1.5 rounded-full bg-current" />
                </span>
              )}
              <span>
                {t.label}
                <span className="sr-only">{t.met ? ' (done)' : ' (not yet)'}</span>
              </span>
            </li>
          ))}
        </ul>
      ) : (
        <p className="mt-2.5 flex items-center gap-1.5 text-xs text-ink-2">
          <Check aria-hidden strokeWidth={2.5} className="size-3.5 text-success" />
          Great password. Keep it somewhere safe.
        </p>
      )}
    </div>
  )
}

/** Error or notice above a form's submit button. */
export function FormNote({ tone, children }: { tone: 'error' | 'info'; children: ReactNode }) {
  return (
    <p role={tone === 'error' ? 'alert' : 'status'} className={cn('rounded-xl px-4 py-3 text-sm font-medium', tone === 'error' ? 'bg-danger-bg text-danger' : 'bg-info-bg text-brand-ink')}>
      {children}
    </p>
  )
}

/**
 * Six-digit code entry: one real input (paste, autofill and screen readers
 * all work) drawn as six boxes.
 */
export function CodeInput({ value, onChange, id, invalid, describedBy }: { value: string; onChange: (v: string) => void; id?: string; invalid?: boolean; describedBy?: string }) {
  const ref = useRef<HTMLInputElement>(null)
  const [focused, setFocused] = useState(false)
  return (
    <div className="relative" onClick={() => ref.current?.focus()}>
      <input
        ref={ref}
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, 6))}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={6}
        aria-invalid={invalid || undefined}
        aria-describedby={describedBy}
        className="absolute inset-0 size-full opacity-0"
        autoFocus
      />
      <div aria-hidden className="grid grid-cols-6 gap-2 sm:gap-2.5">
        {Array.from({ length: 6 }, (_, i) => {
          const active = focused && (i === value.length || (i === 5 && value.length === 6))
          return (
            <div
              key={i}
              className={cn(
                'grid h-14 place-items-center rounded-xl bg-sunken font-mono text-xl font-semibold text-ink tabular-nums shadow-[inset_0_0_0_1px_var(--line)] transition-shadow duration-150',
                active && 'shadow-[inset_0_0_0_2px_var(--brand)]',
                invalid && 'shadow-[inset_0_0_0_2px_var(--danger)]',
              )}
            >
              {value[i] ?? ''}
            </div>
          )
        })}
      </div>
    </div>
  )
}

/** "Resend in 42s", then a button. */
export function ResendCode({ cooldown, busy, onResend }: { cooldown: number; busy: boolean; onResend: () => void }) {
  return (
    <p className="text-center text-sm text-ink-2" aria-live="polite">
      Didn't get it?{' '}
      {cooldown > 0 ? (
        <span>
          Resend in <span className="tabular-nums">{cooldown}s</span>
        </span>
      ) : (
        <button type="button" disabled={busy} onClick={onResend} className="font-semibold text-brand-ink hover:underline disabled:opacity-60">
          {busy ? 'Sending…' : 'Resend code'}
        </button>
      )}
    </p>
  )
}

/** The app's "Continue with Google" button (assets/svg/google_g.svg). */
export function GoogleButton({ onClick, loading, label = 'Continue with Google' }: { onClick: () => void; loading?: boolean; label?: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={loading}
      className="inline-flex h-12 w-full items-center justify-center gap-2.5 rounded-xl bg-surface text-[15px] font-semibold text-ink shadow-[var(--shadow-sm)] transition-[scale,background-color] duration-150 hover:bg-surface-2 active:scale-[0.96] disabled:opacity-60"
    >
      <svg aria-hidden viewBox="0 0 24 24" className={cn('size-[19px]', loading && 'animate-pulse')}>
        <path fill="#4285F4" d="M23.5 12.27c0-.85-.08-1.67-.22-2.45H12v4.64h6.45a5.52 5.52 0 0 1-2.39 3.62v3h3.87c2.26-2.08 3.57-5.15 3.57-8.81Z" />
        <path fill="#34A853" d="M12 24c3.24 0 5.96-1.07 7.94-2.9l-3.87-3c-1.08.72-2.45 1.15-4.07 1.15-3.13 0-5.78-2.11-6.73-4.95h-4v3.1A12 12 0 0 0 12 24Z" />
        <path fill="#FBBC05" d="M5.27 14.3a7.2 7.2 0 0 1 0-4.6V6.6h-4a12 12 0 0 0 0 10.8l4-3.1Z" />
        <path fill="#EA4335" d="M12 4.75c1.76 0 3.35.6 4.6 1.8l3.43-3.43A11.5 11.5 0 0 0 12 0 12 12 0 0 0 1.27 6.6l4 3.1C6.22 6.86 8.87 4.75 12 4.75Z" />
      </svg>
      {label}
    </button>
  )
}

export function OrDivider() {
  return (
    <div className="flex items-center gap-3 text-xs font-medium text-ink-3" role="separator">
      <span className="h-px flex-1 bg-line" />
      or
      <span className="h-px flex-1 bg-line" />
    </div>
  )
}
