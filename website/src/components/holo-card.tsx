import { ClipboardList, Code2, Palette, type LucideIcon } from 'lucide-react'
import { motion, useMotionTemplate, useMotionValue, useReducedMotion, useSpring, useTransform } from 'motion/react'
import { useRef, type PointerEvent } from 'react'
import { cn } from '@/lib/utils'

// A trading-card style member card. On hover it tilts toward the pointer,
// a holographic foil slides across it and a glare follows the cursor.
//
// Motion notes (from the skills):
// - The pointer drives it, so the tilt rides a spring that keeps velocity
//   (to-spring-or-not-to-spring) and settles without wobble.
// - The tilt is transform-only; the foil and glare repaint only this card's
//   own small layers; the lift shadow fades a separate layer's opacity
//   instead of animating box-shadow (60fps-animation, fixing-motion-performance).
// - Reduced motion: the card stays flat and the shine is off.

const roleIcon: Record<string, LucideIcon> = { 'Project Manager': ClipboardList, Hipster: Palette, Hacker: Code2 }

const TILT = 14 // degrees at the card's edge
const spring = { stiffness: 220, damping: 22, mass: 0.6 }

export function HoloCard({ name, role, photo }: { name: string; role: string; photo: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const rect = useRef<DOMRect | null>(null)
  const reduce = useReducedMotion()

  // Pointer position over the card, 0..1 on each axis; 0.5 is the centre.
  const px = useMotionValue(0.5)
  const py = useMotionValue(0.5)
  const active = useMotionValue(0)
  const sx = useSpring(px, spring)
  const sy = useSpring(py, spring)
  const on = useSpring(active, { stiffness: 300, damping: 30 })

  const rotateY = useTransform(sx, [0, 1], [-TILT, TILT])
  const rotateX = useTransform(sy, [0, 1], [TILT * 0.85, -TILT * 0.85])
  const scale = useTransform(on, [0, 1], [1, 1.03])

  // Glare sits under the pointer; the foil drifts the opposite way, which is
  // what makes it read as a reflective surface rather than a sticker.
  const gx = useTransform(sx, (v) => `${v * 100}%`)
  const gy = useTransform(sy, (v) => `${v * 100}%`)
  const fx = useTransform(sx, (v) => `${100 - v * 100}%`)
  const fy = useTransform(sy, (v) => `${100 - v * 100}%`)
  const glare = useMotionTemplate`radial-gradient(farthest-corner circle at ${gx} ${gy}, rgba(255,255,255,0.75) 0%, rgba(255,255,255,0.25) 20%, rgba(255,255,255,0) 50%)`
  const foilPos = useMotionTemplate`${fx} ${fy}`
  const foilOpacity = useTransform(on, [0, 1], [0, 0.5])
  const glareOpacity = useTransform(on, [0, 1], [0, 0.6])

  const Icon = roleIcon[role] ?? Code2

  // Measured once per hover (the box changes as the card tilts), and again
  // only if the page has scrolled since, so the tilt keeps aiming right.
  const measuredAt = useRef(0)
  function measure() {
    rect.current = ref.current!.getBoundingClientRect()
    measuredAt.current = window.scrollY
  }
  function onEnter(e: PointerEvent) {
    if (reduce) return
    measure()
    active.set(1)
    onMove(e)
  }
  function onMove(e: PointerEvent) {
    if (reduce || !rect.current) return
    if (window.scrollY !== measuredAt.current) measure()
    const r = rect.current
    px.set(Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)))
    py.set(Math.min(1, Math.max(0, (e.clientY - r.top) / r.height)))
  }
  function onLeave() {
    rect.current = null
    px.set(0.5)
    py.set(0.5)
    active.set(0)
  }

  return (
    <motion.div
      ref={ref}
      onPointerEnter={onEnter}
      onPointerMove={onMove}
      onPointerLeave={onLeave}
      onPointerCancel={onLeave}
      style={reduce ? undefined : { rotateX, rotateY, scale, transformPerspective: 900 }}
      className="relative mx-auto w-full max-w-[290px] [transform-style:preserve-3d]"
    >
      {/* Lift: a pre-rendered shadow layer that only changes opacity. */}
      <motion.div aria-hidden style={{ opacity: on }} className="absolute inset-2 -z-10 rounded-[22px] shadow-[0_30px_60px_-12px_rgba(0,0,0,0.45)] dark:shadow-[0_30px_60px_-12px_rgba(79,177,246,0.35)]" />

      {/* Foil border: outer radius 22 = inner 19 + 3px padding (better-ui). */}
      <div className="relative overflow-hidden rounded-[22px] bg-gradient-to-br from-[#4FB1F6] via-[#3A6FD4] to-[#8ACDFA] p-[3px] shadow-md">
        <div className="relative flex flex-col rounded-[19px] bg-surface p-3">
          <div className="flex items-center justify-between gap-2 px-1 pb-2">
            <h3 className="truncate font-display text-[15px] font-extrabold text-ink">{name}</h3>
            <img src="/img/brand-mark.png" alt="" className="no-outline size-6 shrink-0 rounded-md" />
          </div>

          <div className="relative aspect-[4/5] overflow-hidden rounded-[8px] bg-[#f2f2f3] ring-1 ring-black/10 dark:ring-white/10">
            <img src={photo} alt={`Portrait of ${name}`} width={452} height={460} loading="lazy" decoding="async" className="no-outline size-full object-cover object-top" />
          </div>

          <div className="mt-3 flex items-center gap-2 px-1">
            <span className="grid size-8 place-items-center rounded-lg bg-info-bg text-brand">
              <Icon aria-hidden className="size-4" strokeWidth={2.25} />
            </span>
            <span className="text-sm font-semibold text-ink">{role}</span>
          </div>
        </div>

        {/* Holographic foil: repeating rainbow stripes that sweep as the card
            turns, colour-dodged so they light up the photo and the foil
            border the way a holo card's art window does. */}
        {!reduce ? (
          <>
            <motion.div
              aria-hidden
              style={{ opacity: foilOpacity, backgroundPosition: foilPos }}
              className={cn(
                'pointer-events-none absolute inset-0 rounded-[22px] mix-blend-color-dodge',
                // Narrow bands with clear gaps: reads as sweeping foil, not a tint over faces.
                'bg-[length:300%_300%] bg-[repeating-linear-gradient(115deg,transparent_0%,rgba(255,60,150,0.35)_3%,rgba(255,200,40,0.3)_5%,rgba(60,255,180,0.3)_7%,rgba(60,190,255,0.35)_9%,rgba(150,100,255,0.35)_11%,transparent_14%,transparent_24%)]',
              )}
            />
            <motion.div aria-hidden style={{ opacity: glareOpacity, backgroundImage: glare }} className="pointer-events-none absolute inset-0 rounded-[22px]" />
          </>
        ) : null}
      </div>
    </motion.div>
  )
}
