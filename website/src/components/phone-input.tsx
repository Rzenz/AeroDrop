import { type InputHTMLAttributes } from 'react'
import { formatPhLocal, phLocalDigits } from '@/lib/phone'
import { cn } from '@/lib/utils'

/**
 * Philippine mobile numbers only. The +63 country code is fixed in front, the
 * field takes digits only (pasted 09…/+63… numbers are trimmed to the 10-digit
 * local part) and stops at 10 digits, shown as "917 123 4567".
 */
export function PhPhoneInput({
  value,
  onChange,
  className,
  size = 'lg',
  ...props
}: Omit<InputHTMLAttributes<HTMLInputElement>, 'value' | 'onChange' | 'size' | 'type'> & {
  value: string
  onChange: (formatted: string) => void
  size?: 'md' | 'lg'
}) {
  return (
    <div
      className={cn(
        'flex w-full items-stretch overflow-hidden rounded-xl bg-sunken shadow-[inset_0_0_0_1px_var(--line)] transition-shadow duration-150 ease-out',
        'focus-within:shadow-[inset_0_0_0_2px_var(--brand)] has-[input[aria-invalid=true]]:shadow-[inset_0_0_0_2px_var(--danger)]',
        size === 'lg' ? 'h-11 text-[15px]' : 'h-11 text-sm',
        className,
      )}
    >
      <span aria-hidden className="flex shrink-0 items-center gap-1.5 border-e border-line ps-3.5 pe-3 font-medium text-ink-2 select-none">
        <span className="text-[11px] font-bold tracking-wide text-ink-3">PH</span>+63
      </span>
      <input
        {...props}
        type="tel"
        inputMode="numeric"
        autoComplete="tel-national"
        placeholder={props.placeholder ?? '917 123 4567'}
        value={value}
        onChange={(e) => onChange(formatPhLocal(phLocalDigits(e.target.value)))}
        className="min-w-0 flex-1 bg-transparent px-3 text-ink tabular-nums placeholder:text-ink-3 focus:outline-none"
        aria-describedby={props['aria-describedby']}
      />
    </div>
  )
}
