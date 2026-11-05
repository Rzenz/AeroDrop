import { Link } from 'react-router-dom'
import { PLAY_STORE_URL } from '@/lib/config'
import { cn } from '@/lib/utils'

export function Logo({ className, to = '/', label = true }: { className?: string; to?: string; label?: boolean }) {
  return (
    <Link to={to} className={cn('inline-flex items-center gap-2.5 rounded-lg', className)} aria-label="AeroDrop home">
      <img src="/img/brand-mark.png" alt="" width={32} height={32} className="size-8 rounded-[10px]" />
      {label ? <span className="font-display text-lg font-extrabold text-ink">AeroDrop</span> : null}
    </Link>
  )
}

/** Google Play badge, drawn in the store's black-badge style. */
export function PlayStoreButton({ className, size = 'md' }: { className?: string; size?: 'md' | 'lg' }) {
  if (!PLAY_STORE_URL) return null
  return (
    <a
      href={PLAY_STORE_URL}
      target="_blank"
      rel="noreferrer"
      className={cn(
        'inline-flex items-center gap-3 rounded-xl bg-[#0b0b0b] text-white shadow-sm ring-1 ring-white/15 transition-transform duration-150 ease-out hover:bg-black active:scale-[0.96]',
        size === 'lg' ? 'h-14 px-5' : 'h-12 px-4',
        className,
      )}
    >
      <svg aria-hidden viewBox="0 0 24 26" className={size === 'lg' ? 'size-7' : 'size-6'}>
        <path fill="#34A853" d="M1.1.6C.8.9.6 1.4.6 2v22c0 .6.2 1.1.5 1.4l.1.1L13.4 13.4v-.3L1.2.5z" />
        <path fill="#FBBC04" d="m17.5 17.5-4.1-4.1v-.3l4.1-4.1.1.1 4.9 2.8c1.4.8 1.4 2.1 0 2.9l-4.9 2.8z" />
        <path fill="#EA4335" d="M17.6 17.4 13.4 13.2 1.1 25.4c.5.5 1.2.5 2.1.1l14.4-8.1" />
        <path fill="#4285F4" d="M17.6 9 3.2.8C2.3.3 1.6.4 1.1.9l12.3 12.3z" />
      </svg>
      <span className="flex flex-col items-start leading-none">
        <span className="text-[10px] font-medium tracking-wide uppercase">Get it on</span>
        <span className={cn('font-display font-semibold', size === 'lg' ? 'text-xl' : 'text-lg')}>Google Play</span>
      </span>
    </a>
  )
}

/**
 * Uiverse ripple button (Javierrocadev / hard-cheetah-69, MIT), recoloured to
 * the brand and shortened from 500ms to 300ms.
 */
export function RippleLink({ to, children, className }: { to: string; children: string; className?: string }) {
  return (
    <Link
      to={to}
      className={cn(
        'group relative isolate inline-flex h-12 items-center justify-center overflow-hidden rounded-xl bg-[#2C56AC] px-6 font-display font-bold text-white shadow-sm transition-transform duration-150 ease-out active:scale-[0.96]',
        className,
      )}
    >
      {[
        ['size-48', 'bg-[#2C56AC]', 'group-hover:delay-75'],
        ['size-40', 'bg-[#3A6FD4]', 'group-hover:delay-100'],
        ['size-32', 'bg-[#4A82E2]', 'group-hover:delay-150'],
        ['size-24', 'bg-[#4FA0EE]', 'group-hover:delay-200'],
        ['size-16', 'bg-[#4FB1F6]', 'group-hover:delay-[250ms]'],
      ].map(([s, c, d]) => (
        <span key={s} aria-hidden className={cn('absolute -z-10 scale-0 rounded-full transition-transform duration-300 ease-out group-hover:scale-150', s, c, d)} />
      ))}
      {children}
    </Link>
  )
}
