import { useId, type HTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes, type TextareaHTMLAttributes } from 'react'
import { Star } from 'lucide-react'
import type { Tone } from '@/lib/format'
import { initials } from '@/lib/format'
import { cn } from '@/lib/utils'

// ── Card ───────────────────────────────────────────────────────────────────
export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('rounded-2xl bg-surface shadow-md', className)} {...props} />
}

export function CardHeader({ title, description, action, className }: { title: ReactNode; description?: ReactNode; action?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex items-start justify-between gap-4 px-5 pt-5', className)}>
      <div className="min-w-0">
        <h2 className="text-base font-semibold text-ink">{title}</h2>
        {description ? <p className="mt-0.5 text-sm text-ink-3">{description}</p> : null}
      </div>
      {action}
    </div>
  )
}

// ── Badge ──────────────────────────────────────────────────────────────────
const toneClass: Record<Tone, string> = {
  neutral: 'bg-sunken text-ink-2',
  info: 'bg-info-bg text-brand-ink',
  success: 'bg-success-bg text-success',
  warning: 'bg-warning-bg text-warning',
  danger: 'bg-danger-bg text-danger',
}

export function Badge({ tone = 'neutral', children, className, dot }: { tone?: Tone; children: ReactNode; className?: string; dot?: boolean }) {
  return (
    <span className={cn('inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap', toneClass[tone], className)}>
      {dot ? <span aria-hidden className="size-1.5 rounded-full bg-current" /> : null}
      {children}
    </span>
  )
}

// ── Form fields ────────────────────────────────────────────────────────────
const control =
  'w-full rounded-xl bg-sunken px-3.5 text-sm text-ink placeholder:text-ink-3 shadow-[inset_0_0_0_1px_var(--line)] ' +
  'transition-shadow duration-150 ease-out focus:outline-none focus:shadow-[inset_0_0_0_2px_var(--brand)] ' +
  'aria-[invalid=true]:shadow-[inset_0_0_0_2px_var(--danger)] disabled:opacity-60'

interface FieldProps {
  label: string
  hint?: string
  error?: string | null
  className?: string
  children: (props: { id: string; 'aria-describedby'?: string; 'aria-invalid'?: boolean }) => ReactNode
}

/** Label + control + hint/error, wired with aria-describedby (fixing-accessibility). */
export function Field({ label, hint, error, className, children }: FieldProps) {
  const id = useId()
  const describedBy = error ? `${id}-err` : hint ? `${id}-hint` : undefined
  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      <label htmlFor={id} className="text-sm font-medium text-ink">
        {label}
      </label>
      {children({ id, 'aria-describedby': describedBy, 'aria-invalid': error ? true : undefined })}
      {error ? (
        <p id={`${id}-err`} className="text-xs font-medium text-danger">
          {error}
        </p>
      ) : hint ? (
        <p id={`${id}-hint`} className="text-xs text-ink-3">
          {hint}
        </p>
      ) : null}
    </div>
  )
}

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cn(control, 'h-11', className)} {...props} />
}

export function Textarea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={cn(control, 'min-h-24 py-2.5', className)} {...props} />
}

export function Select({ className, children, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select className={cn(control, 'h-11 appearance-none bg-[length:16px] bg-[right_12px_center] bg-no-repeat pr-9', className)} style={{ backgroundImage: "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2394A3C4' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E\")" }} {...props}>
      {children}
    </select>
  )
}

// ── Switch (Uiverse knob switch) ───────────────────────────────────────────
export function Switch({ checked, onChange, label, disabled }: { checked: boolean; onChange: (v: boolean) => void; label: string; disabled?: boolean }) {
  return (
    <span className="uv-switch">
      <input type="checkbox" role="switch" aria-label={label} checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      <span className="uv-track" />
      <span className="uv-knob" />
    </span>
  )
}

// ── Avatar ─────────────────────────────────────────────────────────────────
export function Avatar({ name, src, size = 36, className }: { name?: string | null; src?: string | null; size?: number; className?: string }) {
  if (src) return <img src={src} alt="" width={size} height={size} className={cn('shrink-0 rounded-full object-cover', className)} style={{ width: size, height: size }} />
  return (
    <span
      aria-hidden
      className={cn('grid shrink-0 place-items-center rounded-full bg-gradient-to-b from-[#4FB1F6] to-[#3A6FD4] font-display font-bold text-white', className)}
      style={{ width: size, height: size, fontSize: size * 0.38 }}
    >
      {initials(name)}
    </span>
  )
}

// ── Rating ─────────────────────────────────────────────────────────────────
export function Rating({ value, count, className }: { value: number | null | undefined; count?: number; className?: string }) {
  if (!value) return <span className={cn('text-xs text-ink-3', className)}>No ratings yet</span>
  return (
    <span className={cn('inline-flex items-center gap-1 text-xs font-semibold text-ink', className)}>
      <Star aria-hidden className="size-3.5 fill-[#F0A03C] text-[#F0A03C]" />
      <span className="tabular-nums">{value.toFixed(1)}</span>
      {count != null ? <span className="font-normal text-ink-3 tabular-nums">({count})</span> : null}
      <span className="sr-only">out of 5</span>
    </span>
  )
}

// ── Empty state: one clear next action (baseline-ui) ──────────────────────
export function EmptyState({ icon, title, body, action, className }: { icon?: ReactNode; title: string; body?: string; action?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex flex-col items-center px-6 py-12 text-center', className)}>
      {icon ? <div className="mb-4 grid size-12 place-items-center rounded-2xl bg-info-bg text-brand">{icon}</div> : null}
      <h3 className="text-base font-semibold text-ink">{title}</h3>
      {body ? <p className="mt-1 max-w-sm text-sm text-ink-3">{body}</p> : null}
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  )
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex items-center justify-between gap-3 rounded-xl bg-danger-bg px-4 py-3 text-sm text-danger">
      <span>{message}</span>
      {onRetry ? (
        <button type="button" onClick={onRetry} className="font-semibold underline underline-offset-2">
          Retry
        </button>
      ) : null}
    </div>
  )
}

/** Placeholder tile for products without a photo: initials on a tinted field. */
export function ProductArt({ name, src, className }: { name: string; src?: string | null; className?: string }) {
  if (src) return <img src={src} alt="" className={cn('size-full object-cover', className)} />
  const hue = [...name].reduce((h, c) => h + c.charCodeAt(0), 0) % 4
  // Soft pastels on white; deep tints on black so the tiles don't glare.
  const tints = [
    'from-[#E5F1FE] to-[#CFE4FC] dark:from-[#0c1a2c] dark:to-[#11243c]',
    'from-[#E3F6EE] to-[#CBEEDF] dark:from-[#0a1f17] dark:to-[#0e2b20]',
    'from-[#FDF1DF] to-[#FBE3BF] dark:from-[#241907] dark:to-[#31220a]',
    'from-[#EEE9FD] to-[#DCD3FB] dark:from-[#17122a] dark:to-[#201939]',
  ]
  return (
    <div aria-hidden className={cn('grid size-full place-items-center bg-gradient-to-br font-display text-2xl font-bold text-black/50 dark:text-white/60', tints[hue], className)}>
      {initials(name)}
    </div>
  )
}
