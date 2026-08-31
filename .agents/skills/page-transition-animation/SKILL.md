---
name: page-transition-animation
description: Page and route transition patterns for mobile and web apps, including smooth enter/exit animations, crossfades, slide transitions, and shared-element transitions.
---

# Page & Route Transition Animation

Smooth page transitions require clean separation between the persistent shell and unmounting/mounting route views.

## Principles

- **Durations**: Keep page transitions between **200ms – 350ms**. Anything longer makes navigation feel sluggish.
- **Asymmetric Curves**: Exit fast with ease-in (`~150-200ms`), enter smooth with ease-out (`~250-300ms`).
- **Directional Continuity**: Moving forward in a flow slides in from right/bottom; navigating back slides out to right/bottom.
- **Shared Elements**: Anchor the user's focus with hero images, headers, or cards that smoothly morph between screens.
- **Reduced Motion**: Fall back to simple instantaneous opacity cross-fades when `prefers-reduced-motion` is enabled.

## Quick Reference

| Transition Type | Recommended Timing | Curve |
| :--- | :--- | :--- |
| **Crossfade** | 200ms | `cubic-bezier(0.4, 0.0, 0.2, 1)` |
| **Push / Slide Forward** | 280ms | `cubic-bezier(0.0, 0.0, 0.2, 1)` (ease-out) |
| **Pop / Slide Back** | 240ms | `cubic-bezier(0.4, 0.0, 1, 1)` (ease-in) |
| **Bottom Sheet / Modal** | 300ms | Spring (`stiffness: 400, damping: 32`) |
