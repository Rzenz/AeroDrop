import { ArrowLeft, CloudSun, MapPin, ShieldCheck } from 'lucide-react'
import { useRef, useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { Logo, PlayStoreButton } from '@/components/brand'
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
      className="group -ml-3 inline-flex h-11 w-fit items-center gap-1.5 rounded-xl ps-2.5 pe-3 text-sm font-semibold text-ink-2 transition-[background-color,color,transform] duration-150 ease-out hover:bg-sunken hover:text-ink active:scale-[0.96]"
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

export function AuthShell({
  title,
  subtitle,
  children,
  footer,
  onBack,
  backLabel,
  showBack = true,
}: {
  title: string
  subtitle?: ReactNode
  children: ReactNode
  footer?: ReactNode
  /** Step-level back (e.g. code entry → form). Defaults to leaving the page. */
  onBack?: () => void
  backLabel?: string
  showBack?: boolean
}) {
  const goBack = useGoBack()
  return (
    <div className="grid min-h-dvh bg-bg lg:grid-cols-[minmax(0,1fr)_minmax(0,0.9fr)]">
      <div className="flex flex-col px-4 py-6 pt-[max(1.5rem,env(safe-area-inset-top))] sm:px-10">
        <Logo />
        <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center py-10">
          {showBack ? <BackButton onClick={onBack ?? goBack} label={backLabel} /> : null}
          <h1 className={cn('font-display text-3xl font-extrabold text-ink', showBack && 'mt-4')}>{title}</h1>
          {subtitle ? <p className="mt-2 text-ink-2">{subtitle}</p> : null}
          <div className="mt-8">{children}</div>
          {footer ? <div className="mt-8 text-sm text-ink-2">{footer}</div> : null}
        </main>
      </div>
      <aside data-theme="dark" className="relative hidden overflow-hidden bg-black p-10 lg:flex lg:flex-col lg:justify-end">
        <img src="/img/uclm-campus.jpg" alt="" className="no-outline absolute inset-0 size-full object-cover opacity-25" />
        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/70 to-transparent" />
        <div className="relative max-w-md">
          <p className="font-display text-3xl font-extrabold text-white">Campus orders, delivered by drone.</p>
          <ul className="mt-6 space-y-3 text-[#d4d4d8]">
            <li className="flex gap-3"><MapPin aria-hidden className="mt-0.5 size-5 shrink-0 text-[#4FB1F6]" />Four drop-off buildings across UCLM</li>
            <li className="flex gap-3"><CloudSun aria-hidden className="mt-0.5 size-5 shrink-0 text-[#4FB1F6]" />Flights paused automatically in unsafe weather</li>
            <li className="flex gap-3"><ShieldCheck aria-hidden className="mt-0.5 size-5 shrink-0 text-[#4FB1F6]" />A one-time code at every sign-in</li>
          </ul>
          <div className="mt-8">
            <PlayStoreButton />
          </div>
        </div>
      </aside>
    </div>
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
      <div aria-hidden className="grid grid-cols-6 gap-2">
        {Array.from({ length: 6 }, (_, i) => {
          const active = focused && (i === value.length || (i === 5 && value.length === 6))
          return (
            <div
              key={i}
              className={cn(
                'grid h-14 place-items-center rounded-xl bg-sunken font-mono text-xl font-semibold text-ink shadow-[inset_0_0_0_1px_var(--line)] transition-shadow duration-150',
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

/** The app's "Continue with Google" button (assets/svg/google_g.svg). */
export function GoogleButton({ onClick, loading, label = 'Continue with Google' }: { onClick: () => void; loading?: boolean; label?: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={loading}
      className="inline-flex h-12 w-full items-center justify-center gap-2.5 rounded-xl bg-surface text-sm font-semibold text-ink shadow-sm transition-[transform,background-color] duration-150 hover:bg-surface-2 active:scale-[0.96] disabled:opacity-60"
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
