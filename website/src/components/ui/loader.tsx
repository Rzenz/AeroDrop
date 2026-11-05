import { cn } from '@/lib/utils'

/** Uiverse ring spinner (Clemix37), currentColor-driven. */
export function Spinner({ size = 20, className }: { size?: number; className?: string }) {
  return <span aria-hidden className={cn('uv-spinner', className)} style={{ ['--size' as string]: `${size}px` }} />
}

/** Uiverse bounce dots (Javierrocadev). */
export function Dots({ className }: { className?: string }) {
  return (
    <span aria-hidden className={cn('uv-dots inline-flex gap-1.5', className)}>
      <span className="size-2.5 rounded-full bg-brand" />
      <span className="size-2.5 rounded-full bg-brand" />
      <span className="size-2.5 rounded-full bg-brand" />
    </span>
  )
}

export function PageLoader({ label = 'Loading' }: { label?: string }) {
  return (
    <div role="status" className="grid min-h-[40dvh] place-items-center">
      <div className="flex flex-col items-center gap-3 text-sm text-ink-3">
        <Dots />
        <span>{label}…</span>
      </div>
    </div>
  )
}

export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden className={cn('animate-pulse rounded-lg bg-sunken', className)} />
}
