import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach, beforeEach, expect, vi } from 'vitest'

afterEach(() => cleanup())

// Testing appendix: with AERODROP_CAPTURE_DIR set, keep the last states of the
// page while each test runs and save them (before cleanup, which runs after
// this hook), so they can be rendered with the site's CSS into screenshots of
// the exact states the test went through.
const captureDir = process.env.AERODROP_CAPTURE_DIR
const snapshots: string[] = []
if (captureDir) {
  const take = () => {
    const html = document.body.outerHTML
    if (snapshots[snapshots.length - 1] !== html) snapshots.push(html)
    if (snapshots.length > 25) snapshots.shift()
  }
  let queued = false
  new MutationObserver(() => {
    if (queued) return
    queued = true
    queueMicrotask(() => { queued = false; take() })
  }).observe(document, { subtree: true, childList: true, attributes: true, characterData: true })
  beforeEach(() => { snapshots.length = 0 })
  afterEach(async () => {
    const id = /(CASE|INT)-\d+/.exec(expect.getState().currentTestName ?? '')?.[0]
    if (!id) return
    take()
    const { writeFileSync } = await import('node:fs')
    snapshots.forEach((body, k) => writeFileSync(`${captureDir}/${id}_${snapshots.length - 1 - k}.html`, `<!doctype html><html><head></head>${body}</html>`))
  })
}

// jsdom lacks these browser APIs; the pages' animations and layout code call them.
window.matchMedia ??= ((query: string) => ({
  matches: false, media: query, onchange: null,
  addListener: vi.fn(), removeListener: vi.fn(), addEventListener: vi.fn(), removeEventListener: vi.fn(), dispatchEvent: vi.fn(),
})) as unknown as typeof window.matchMedia
globalThis.ResizeObserver ??= class { observe() {} unobserve() {} disconnect() {} } as unknown as typeof ResizeObserver
globalThis.IntersectionObserver ??= class { observe() {} unobserve() {} disconnect() {} takeRecords() { return [] } root = null; rootMargin = ''; thresholds = [] } as unknown as typeof IntersectionObserver
Element.prototype.scrollIntoView ??= vi.fn()
Element.prototype.scrollTo ??= vi.fn() as unknown as typeof Element.prototype.scrollTo
