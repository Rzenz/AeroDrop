---
name: 60fps-animation
description: "Web and mobile animation performance guidance for avoiding layout thrashing and reaching smooth 60/120fps motion with compositor-friendly techniques. Use when asked to optimize animation performance, fix stuttering or dropped frames, animate layout or height changes smoothly, or eliminate jank."
---

# 60fps Animation

The rule for 60fps (and 120fps on ProMotion displays): **animate only compositor properties** — `transform` and `opacity`.

Every other animated property triggers layout (reflow) or paint (rasterization) on every frame. Layout recalculates geometry for the element, its children, and often its siblings/ancestors. Paint redraws the pixels into bitmaps. Both run on the main thread and drop frames under contention. Compositor properties are handed to the GPU layer tree: no layout, no repaint, smooth 60fps even when the main thread is busy.

## The golden rule: transform + opacity only

| Property | Triggers | Safe at 60fps? |
|---|---|---|
| `transform` (`translate`, `scale`, `rotate`, `skew`) | Composite only | **YES** |
| `opacity` | Composite only | **YES** |
| `top` / `left` / `right` / `bottom` | Layout + Paint + Composite | **NO** |
| `width` / `height` / `max-height` | Layout + Paint + Composite | **NO** |
| `margin` / `padding` | Layout + Paint + Composite | **NO** |
| `box-shadow` | Paint + Composite | **NO** |
| `filter: blur(...)` / `backdrop-filter` | Paint + Composite | **NO** (use opacity cross-fade) |
| `background-color` / `color` | Paint + Composite | Avoid animating rapidly |

## Shadow on hover: use a pseudo-element

Animating `box-shadow` repaints the blur on every frame. Instead, put the shadow on an `::after` pseudo-element and animate its `opacity`.

```css
.card { position: relative; }
.card::after {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: inherit;
  box-shadow: 0 12px 28px rgba(0,0,0,0.35);
  opacity: 0;
  transition: opacity 300ms ease;
  pointer-events: none;
}
.card:hover::after { opacity: 1; }
```

The blurred shadow is rasterized once; hovering only changes a compositor opacity — smooth at any frame rate.

## FLIP: animate layout changes cheaply

FLIP (First, Last, Invert, Play) animates a *layout* change (reorder, resize, move between containers) using only `transform`. Measure where the element was (First) and will be (Last), apply an inverting transform so it visually appears unmoved, then animate the transform back to identity (Play). The DOM ends in its real final layout; the motion is pure compositor work.

```js
function flip(el, mutate) {
  const first = el.getBoundingClientRect();   // First
  mutate();                                    // change the DOM/layout
  const last = el.getBoundingClientRect();     // Last

  const dx = first.left - last.left;
  const dy = first.top - last.top;
  const sx = first.width  / last.width;
  const sy = first.height / last.height;

  el.animate(
    [
      { transformOrigin: 'top left',
        transform: `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})` }, // Invert
      { transformOrigin: 'top left', transform: 'none' },               // Play
    ],
    { duration: 300, easing: 'cubic-bezier(0.2, 0, 0, 1)' }
  );
}
```

## Animating height: auto

`height: auto` is not interpolatable historically. Modern and fallback approaches:

```css
/* Robust fallback: CSS grid 1fr -> 0fr */
.wrapper {
  display: grid;
  grid-template-rows: 0fr;            /* collapsed */
  transition: grid-template-rows 300ms ease;
}
.wrapper.open { grid-template-rows: 1fr; }
.wrapper > .content { overflow: hidden; min-height: 0; }
```

## Avoid layout thrashing (batch reads, then writes)

Reading a layout property (`offsetWidth`, `getBoundingClientRect`, `scrollTop`, `getComputedStyle`) after a write forces a *synchronous* reflow. Interleaving reads and writes in a loop ("layout thrashing") can run dozens of forced reflows per frame.

```js
// BAD: read, write, read, write... forces reflow each iteration
items.forEach((el) => {
  const w = el.offsetWidth;          // read (forces layout)
  el.style.width = w * 1.5 + 'px';   // write (invalidates layout)
});

// GOOD: batch all reads, then all writes
const widths = items.map((el) => el.offsetWidth);  // all reads
items.forEach((el, i) => {                          // all writes
  el.style.width = widths[i] * 1.5 + 'px';
});
```

## will-change: use sparingly

`will-change: transform` promotes an element to its own compositor layer ahead of time, avoiding a hitch at animation start. But every promoted layer costs GPU memory, and over-use degrades performance.

```css
.menu { will-change: transform; }   /* only on elements about to animate */
```

Rules: apply just before the animation (e.g. on hover/parent state), remove it after (`will-change: auto`) when idle, never blanket-apply to many elements, and never leave it permanently on large/numerous nodes.

## Quick reference

| Goal | Do this |
|---|---|
| Move element | `transform: translate()` |
| Resize without distortion | FLIP with `transform` |
| Shadow on hover | Animate `opacity` of shadow pseudo-element |
| Expand to content height | grid `0fr→1fr`, or `interpolate-size: allow-keywords` |
| Many elements moving | Batch `getBoundingClientRect` reads, then writes |
| Smooth animation start | `will-change` just-in-time, remove when idle |
