import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react'
import { Link, type LinkProps } from 'react-router-dom'
import { cn } from '@/lib/utils'
import { Spinner } from './loader'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'outline'
type Size = 'sm' | 'md' | 'lg'

const base =
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl font-semibold select-none ' +
  'transition-[transform,background-color,color,box-shadow,opacity] duration-150 ease-out ' +
  'active:scale-[0.96] disabled:pointer-events-none disabled:opacity-50'

const variants: Record<Variant, string> = {
  primary: 'bg-brand text-on-brand shadow-sm hover:brightness-110',
  secondary: 'bg-surface text-ink shadow-sm hover:bg-surface-2',
  outline: 'bg-transparent text-ink shadow-[inset_0_0_0_1px_var(--line)] hover:bg-sunken',
  ghost: 'bg-transparent text-ink-2 hover:bg-sunken hover:text-ink',
  danger: 'bg-danger text-white shadow-sm hover:brightness-110 dark:text-black',
}

const sizes: Record<Size, string> = {
  sm: 'h-9 px-3 text-sm',
  md: 'h-11 px-4 text-sm',
  lg: 'h-12 px-6 text-base',
}

export const buttonClass = (variant: Variant = 'primary', size: Size = 'md', className?: string) =>
  cn(base, variants[variant], sizes[size], className)

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  loading?: boolean
  icon?: ReactNode
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', loading, icon, className, children, disabled, type = 'button', ...props },
  ref,
) {
  return (
    <button ref={ref} type={type} disabled={disabled || loading} aria-busy={loading || undefined} className={buttonClass(variant, size, className)} {...props}>
      {loading ? <Spinner size={16} /> : icon}
      {children}
    </button>
  )
})

export function ButtonLink({ variant = 'primary', size = 'md', className, icon, children, ...props }: LinkProps & { variant?: Variant; size?: Size; icon?: ReactNode }) {
  return (
    <Link className={buttonClass(variant, size, className)} {...props}>
      {icon}
      {children}
    </Link>
  )
}

/** Icon-only control; `label` is required so it always has an accessible name. */
export const IconButton = forwardRef<HTMLButtonElement, ButtonHTMLAttributes<HTMLButtonElement> & { label: string; badge?: number }>(
  function IconButton({ label, badge, className, children, type = 'button', ...props }, ref) {
    return (
      <button
        ref={ref}
        type={type}
        aria-label={badge ? `${label} (${badge} unread)` : label}
        className={cn(
          'relative grid size-10 place-items-center rounded-xl text-ink-2 transition-[transform,background-color,color] duration-150 ease-out hover:bg-sunken hover:text-ink active:scale-[0.96]',
          className,
        )}
        {...props}
      >
        {children}
        {badge ? (
          <span aria-hidden className="absolute top-1 right-1 grid min-w-4 place-items-center rounded-full bg-danger px-1 text-[10px] leading-4 font-bold text-white tabular-nums">
            {badge > 9 ? '9+' : badge}
          </span>
        ) : null}
      </button>
    )
  },
)
