# Mobile UI/UX Master Skill

## Description

Activates when creating, refactoring, or reviewing mobile user interfaces, screen layouts, design tokens, frontend components, or wireframes. This skill enforces strict mobile-first ergonomics, design patterns, and platform-specific guidelines.

## Activation Hooks

- Keyword triggers: "mobile UI", "mobile UX", "screen design", "touch target", "thumb zone", "HIG", "Material 3", "responsive layout"
- File triggers: `.tsx`, `.jsx`, `.swift`, `.dart`, `.vue`, `.xml` (layout), `.scss`

## Instructions

### 1. Thumb-Zone Ergonomics & Layout

- Place all high-frequency primary actions (e.g., checkout, submit, main navigation) in the bottom third of the viewport ("The Natural Thumb Zone").
- Reserve the top third of the screen exclusively for low-frequency actions, back buttons, and static information displays.
- Enforce a strict minimum touch target size of 44x44 points (iOS) or 48x48 dp (Android) for all interactive elements.
- Maintain a minimum of 8px padding between adjacent touch targets to eliminate accidental taps.
- Implement sticky bottom sheets or floating action buttons (FABs) instead of fixed desktop-style headers.

### 2. Platform Rules Execution

- **For iOS environments (`.swift`, Apple-focused code):** Enforce Apple Human Interface Guidelines (HIG). Use San Francisco typography scales, strict tab-bar navigation paradigms, and standard SF Symbols.
- **For Android environments (`.xml`, Material-focused code):** Enforce Material Design 3 (M3). Use Roboto/Product Sans scales, explicit surface elevations, 8dp grid alignments, and M3 functional components.
- **For Cross-Platform UI (`.tsx`, `.dart`):** Isolate styles into a uniform design token system. Generate adaptive components that split rendering logic based on the host OS platform check.

### 3. Mobile Performance & Content Constraints

- **Smart Defaults Over Text Inputs:** Never force free-form typing where a native wheel-picker, radio group, toggle, or auto-complete sheet can be used.
- **Data Densification:** Eliminate wide margins. Utilize expandable accordions, horizontal swipeable carousels, and tab segments to keep content scannable without endless vertical scrolling.
- **Micro-interactions:** Every layout change must include explicit state definitions for: Default, Pressed/Active, Loading/Skeleton, and Disabled.
- **Asset Optimization:** Use vector assets (SVGs/SF Symbols/Material Icons) natively. Explicitly define responsive image constraints (`resizeMode: 'cover'`, `aspectRatio`).

## Outputs Format Requirements

- Provide ready-to-paste, fully structured UI component code with clean separation of layout and theme tokens.
- Include a markdown "UX Impact Assessment" table explaining the Ergonomic Choice, Platform Alignment, and Accessibility Compliance (WCAG AAA contrast/targets) for each screen designed.
