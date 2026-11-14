import { AlertTriangle, ArrowLeft, Check, Eye, EyeOff, Moon, Sun } from 'lucide-react'
import { motion } from 'motion/react'
import { useRef, useState, type InputHTMLAttributes, type ReactNode } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { IconButton } from '@/components/ui/button'
import { passwordStrength } from '@/lib/password-strength'
import { setTheme, useTheme } from '@/lib/theme'
import { cn } from '@/lib/utils'

/**
 * Back control for a step inside an auth screen (code entry → form). A real
 * button with a visible label; the arrow nudges left on hover.
 */
export function BackButton({ onClick, label = 'Back', light }: { onClick: () => void; label?: string; light?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'group -ml-2.5 inline-flex h-9 w-fit items-center gap-1.5 rounded-xl ps-2 pe-3 text-sm font-semibold transition-[background-color,color,scale] duration-150 ease-out active:scale-[0.96]',
        light ? 'text-white/85 hover:bg-white/10 hover:text-white' : 'text-ink-2 hover:bg-sunken hover:text-ink',
      )}
    >
      <ArrowLeft aria-hidden strokeWidth={2.25} className="size-4 transition-transform duration-150 ease-out group-hover:-translate-x-0.5" />
      {label}
    </button>
  )
}

/** Previous page in this tab, or the landing page when the visit started here. */
function useGoBack() {
  const navigate = useNavigate()
  return () => {
    const idx = (window.history.state as { idx?: number } | null)?.idx ?? 0
    if (idx > 0) navigate(-1)
    else navigate('/')
  }
}

function ThemeSwitch({ light }: { light?: boolean }) {
  const theme = useTheme()
  return (
    <IconButton
      className={light ? 'text-white/85 hover:bg-white/10 hover:text-white' : undefined}
      label={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'}
      onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
    >
      {theme === 'dark' ? <Sun aria-hidden className="size-5" /> : <Moon aria-hidden className="size-5" />}
    </IconButton>
  )
}

/** The mark and wordmark, linking home. `light` for the dark photo panel. */
function Brand({ light }: { light?: boolean }) {
  return (
    <Link to="/" aria-label="AeroDrop home" className="inline-flex w-fit items-center gap-2.5 rounded-lg">
      <img src="/img/brand-mark.png" alt="" width={36} height={36} className="size-9 rounded-[11px]" />
      <span className={cn('font-display text-lg font-extrabold', light ? 'text-white' : 'text-ink')}>AeroDrop</span>
    </Link>
  )
}

/**
 * The page behind the card: the UCLM campus, softly blurred and washed into
 * the page colour, a faint dot grid and two quiet brand glows. Static, so it
 * costs nothing after the first paint.
 */
function Backdrop() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-bg">
      <img src="/img/uclm-campus.jpg" alt="" className="no-outline absolute inset-0 size-full scale-110 object-cover opacity-70 blur-2xl dark:opacity-50" />
      <div className="absolute inset-0 bg-bg/75 dark:bg-bg/70" />
      <div className="absolute inset-0 [background-image:radial-gradient(var(--line)_1px,transparent_1px)] [background-size:22px_22px] [mask-image:radial-gradient(ellipse_80%_70%_at_50%_50%,black,transparent)]" />
      <div className="absolute -top-40 -left-40 size-[520px] rounded-full bg-[var(--sky)] opacity-20 blur-[120px]" />
      <div className="absolute -right-40 -bottom-40 size-[520px] rounded-full bg-[var(--brand)] opacity-15 blur-[120px]" />
    </div>
  )
}

/**
 * Auth screens. Built to fit one screen without scrolling on a laptop:
 *
 * - `split` (sign-in, create account): one card, a campus photo panel with the
 *   title on the left and the form on the right. Below `md` the panel folds
 *   into a short heading above the form.
 * - otherwise (codes, reset, complete profile): a single compact card.
 */
export function AuthShell({
  title,
  subtitle,
  children,
  footer,
  onBack,
  backLabel,
  split = false,
  wide = false,
  pageBack,
}: {
  title: string
  subtitle?: ReactNode
  children: ReactNode
  footer?: ReactNode
  /** A step-level back (e.g. code entry → form). */
  onBack?: () => void
  backLabel?: string
  /** Kept for older callers; the brand link already leads home. */
  showBack?: boolean
  split?: boolean
  /** A wider form pane (create account). */
  wide?: boolean
  /** Back to the previous page (defaults on for `split` pages). */
  pageBack?: boolean
}) {
  const goBack = useGoBack()
  const showPageBack = pageBack ?? split
  // A step's own back wins over leaving the page.
  const back = onBack ?? (showPageBack ? goBack : undefined)
  const heading = (light?: boolean) => (
    <>
      <h1 className={cn('font-display text-[26px] leading-tight font-extrabold text-balance lg:text-[30px]', light ? 'text-white' : 'text-ink')}>{title}</h1>
      {subtitle ? <p className={cn('mt-2 text-[15px] text-pretty', light ? 'text-[#d4d4d8]' : 'text-ink-2')}>{subtitle}</p> : null}
    </>
  )

  return (
    <div className={cn('relative isolate grid min-h-dvh place-items-center px-4', split ? 'py-4 md:py-5' : 'pt-16 pb-4')}>
      <Backdrop />
      {split ? null : (
        <div className="absolute top-[max(0.75rem,env(safe-area-inset-top))] right-3 sm:right-5">
          <ThemeSwitch />
        </div>
      )}

      <motion.main
        // Opacity only: a moving card would offset the tab pill's layout measurement.
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.25, ease: 'easeOut' }}
        className={cn(
          'w-full overflow-hidden rounded-[28px] bg-surface shadow-[var(--shadow-lg)]',
          split ? cn('grid md:grid-cols-[300px_minmax(0,1fr)] lg:grid-cols-[340px_minmax(0,1fr)]', wide ? 'max-w-[980px]' : 'max-w-[880px]') : 'max-w-[440px]',
        )}
      >
        {split ? (
          <aside data-theme="dark" className="relative hidden flex-col justify-between overflow-hidden bg-black p-8 md:flex lg:p-10">
            <img src="/img/uclm-campus.jpg" alt="" className="no-outline absolute inset-0 size-full object-cover opacity-45" />
            <div className="absolute inset-0 bg-gradient-to-b from-black/70 via-black/55 to-black/90" />
            <div className="relative flex flex-col gap-6">
              <div className="flex items-center justify-between gap-3">
                {back ? <BackButton onClick={back} label={backLabel} light /> : <span />}
                <ThemeSwitch light />
              </div>
              <Brand light />
            </div>
            <div className="relative mt-16">
              {heading(true)}
              {footer ? <div className="mt-8 text-sm text-[#d4d4d8] [&_a]:text-[#8acdfa]">{footer}</div> : null}
            </div>
          </aside>
        ) : null}

        <div className={cn('flex flex-col justify-center', split ? 'p-6 sm:px-8 sm:py-7 lg:px-10' : 'p-6 sm:p-8')}>
          {/* The heading above the form: always on the single card, phones only on split. */}
          <div className={cn('mb-6', split && 'md:hidden')}>
            {split ? (
              <div className="mb-5 flex items-center justify-between gap-3">
                {back ? <BackButton onClick={back} label={backLabel} /> : <span />}
                <ThemeSwitch />
              </div>
            ) : null}
            <div className="flex items-center justify-between gap-3">
              <Brand />
              {!split && back ? <BackButton onClick={back} label={backLabel} /> : null}
            </div>
            <div className="mt-6">{heading()}</div>
          </div>
          {children}
          {footer ? <div className={cn('mt-6 text-center text-sm text-ink-2', split && 'md:hidden')}>{footer}</div> : null}
        </div>
      </motion.main>
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
          'h-11 w-full rounded-xl bg-sunken px-4 text-[15px] text-ink placeholder:text-ink-3 shadow-[inset_0_0_0_1px_var(--line)] transition-shadow duration-150 ease-out',
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
  const missing = s.tips.filter((t) => !t.met).map((t) => t.hint)
  const advice = s.warning ?? (missing.length ? `Add ${listOf(missing)}.` : 'Great password. Keep it somewhere safe.')
  return (
    <div id={id}>
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
      <p className={cn('mt-1.5 flex items-start gap-1.5 text-xs text-pretty', s.warning ? 'font-medium text-warning' : s.level === 4 ? 'text-ink-2' : 'text-ink-3')}>
        {s.warning ? <AlertTriangle aria-hidden className="mt-px size-3.5 shrink-0" /> : s.level === 4 ? <Check aria-hidden strokeWidth={2.5} className="mt-px size-3.5 shrink-0 text-success" /> : null}
        <span>
          <span className="sr-only">Tip: </span>
          {advice}
        </span>
      </p>
    </div>
  )
}

/** "a, b and c" */
const listOf = (items: string[]) => (items.length < 2 ? items.join('') : `${items.slice(0, -1).join(', ')} and ${items.at(-1)}`)

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
