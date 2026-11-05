import { AnimatePresence, motion } from 'motion/react'
import { CircleAlert, CircleCheck, Info, X } from 'lucide-react'
import { createStore, useStore } from '@/lib/store'
import { cn } from '@/lib/utils'

type Kind = 'success' | 'error' | 'info'
interface ToastItem {
  id: number
  kind: Kind
  message: string
}

const toasts = createStore<ToastItem[]>([])
let next = 1

export function toast(message: string, kind: Kind = 'success') {
  const id = next++
  toasts.set((t) => [...t.slice(-2), { id, kind, message }])
  setTimeout(() => dismiss(id), kind === 'error' ? 6000 : 3500)
}
const dismiss = (id: number) => toasts.set((t) => t.filter((x) => x.id !== id))

const icons = { success: CircleCheck, error: CircleAlert, info: Info }

/** Toasts confirm; they never carry the only copy of an error (fixing-accessibility). */
export function Toaster() {
  const items = useStore(toasts)
  return (
    <div
      aria-live="polite"
      className="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex flex-col items-center gap-2 p-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:items-end"
    >
      <AnimatePresence initial={false}>
        {items.map((t) => {
          const Icon = icons[t.kind]
          return (
            <motion.div
              key={t.id}
              layout
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0, transition: { duration: 0.2, ease: 'easeOut' } }}
              exit={{ opacity: 0, y: 8, transition: { duration: 0.15, ease: 'easeIn' } }}
              role={t.kind === 'error' ? 'alert' : 'status'}
              className="pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-xl bg-surface p-3 pr-2 shadow-lg"
            >
              <Icon
                aria-hidden
                className={cn('mt-0.5 size-5 shrink-0', t.kind === 'success' && 'text-success', t.kind === 'error' && 'text-danger', t.kind === 'info' && 'text-brand')}
              />
              <p className="flex-1 text-sm text-ink">{t.message}</p>
              <button
                type="button"
                onClick={() => dismiss(t.id)}
                aria-label="Dismiss"
                className="grid size-8 place-items-center rounded-lg text-ink-3 transition-colors duration-150 hover:bg-sunken hover:text-ink"
              >
                <X aria-hidden className="size-4" />
              </button>
            </motion.div>
          )
        })}
      </AnimatePresence>
    </div>
  )
}
