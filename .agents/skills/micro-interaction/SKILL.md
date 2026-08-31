---
name: micro-interaction
description: UI motion guidance for hover and press feedback, toggles, toasts, drawers, modals, list transitions, and shared-element interactions. Use when adding interactive micro-animations or state feedback.
---

# Micro-Interactions

Small, functional motion that makes an interface feel responsive and alive: hover/press/focus feedback, toggles, toasts, drawers, and list/layout animation. The goal is feedback and continuity, not decoration.

## When to use

- Hover/press/focus feedback; toggles, checkboxes, like/heart buttons
- Toasts/snackbars, drawers, modals, tooltips, accordions (enter/exit)
- List add/remove/reorder; shared-element ("magic move") layout transitions
- Loading → success → error state transitions

## Principles

- Duration: UI micro-interactions live in **100–250ms**. Anything over ~400ms feels laggy for a click response.
- Animate `transform` and `opacity` only — they are GPU-composited (no layout/paint). Avoid animating `width/height/top/left`; use `scale` or layout animation instead.
- Give **instant** press feedback: `scale: 0.96` on tap with a fast spring.
- Asymmetric timing: enter slightly slower (ease-out), exit faster (ease-in). Things should arrive gracefully and leave promptly.
- Respect `prefers-reduced-motion`: gate non-essential motion; keep opacity changes, drop large movement.
- Easing defaults: enter `cubic-bezier(0.16, 1, 0.3, 1)`; tasteful overshoot `cubic-bezier(0.34, 1.56, 0.64, 1)`; standard move `cubic-bezier(0.4, 0, 0.2, 1)`.

## Quick Reference

| Need | Approach |
|------|----------|
| Press feedback | scale 0.96 with fast spring (stiffness: 400, damping: 30) |
| Enter/exit | Asymmetric timing (enter ease-out ~200ms, exit ease-in ~150ms) |
| Reorder / resize | Layout transform interpolation |
| Magic move | Shared hero / element ID transitions |
| Accessibility | `prefers-reduced-motion` guard always |
