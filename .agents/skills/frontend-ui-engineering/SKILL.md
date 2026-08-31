---
name: frontend-ui-engineering
description: Frontend UI engineering guidance covering component architecture, responsive design, accessibility, state management, and anti-AI-slop design system adherence.
---

# Frontend UI Engineering

Frontend engineering guidance emphasizing production-grade craft, accessibility, performance, and clean design system adherence.

## Architecture

- Split Container (data/state) from Presentation (pure UI) components.
- Avoid prop drilling deeper than 3 levels; structure component hierarchy cleanly.
- Keep components focused and under ~200 lines.

## Anti-AI Aesthetic Rules

- **Colors**: Never use generic default purple/indigo gradients. Use tailored, intentional semantic color palettes.
- **Radii**: Match the design system's border radius scale rather than applying indiscriminate oversized rounding.
- **Copy**: Never use Lorem Ipsum; use realistic domain content to catch wrapping and overflow early.
- **Spacing**: Use strict spacing token scales (4px, 8px, 12px, 16px, 24px, 32px), never arbitrary pixel values.

## Accessibility (WCAG 2.1 AA)

- All interactive controls must be focusable and operable by keyboard.
- Proper ARIA labels and touch target sizes (minimum 44×44px).
- Provide distinct loading, error, and empty states.
- High contrast (minimum 4.5:1 for body text, 3:1 for large text).
