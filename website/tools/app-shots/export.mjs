// Exports real AeroDrop app screens into website/public/app as WebP.
// The harness (./harness) runs the unmodified Flutter app against the mock
// backend (./mock); this script drives it in Chrome. Run via ./capture.sh.
import { chromium } from 'playwright-core'
import { mkdirSync, writeFileSync } from 'node:fs'
import { ids } from './mock/data.mjs'

const BASE = `http://localhost:${process.env.PORT ?? 7070}`
const OUT = new URL('../../public/app/', import.meta.url).pathname
const CHROME = process.env.CHROME_PATH ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const NOW = Number(process.env.MOCK_NOW ?? Date.parse('2026-11-05T11:42:00+08:00'))
mkdirSync(OUT, { recursive: true })

// Shift the browser clock to NOW without faking timers (Flutter keeps animating).
const shiftClock = (target) => {
  const off = target - Date.now()
  const R = Date
  class D extends R {
    constructor(...a) { super(...(a.length ? a : [R.now() + off])) }
    static now() { return R.now() + off }
  }
  globalThis.Date = D
}

const b = await chromium.launch({ executablePath: CHROME, headless: true })
const converter = await b.newPage()
async function save(name, png) {
  const webp = await converter.evaluate(async (b64) => {
    const img = new Image()
    img.src = `data:image/png;base64,${b64}`
    await img.decode()
    const c = Object.assign(document.createElement('canvas'), { width: img.width, height: img.height })
    c.getContext('2d').drawImage(img, 0, 0)
    return c.toDataURL('image/webp', 0.9).split(',')[1]
  }, png.toString('base64'))
  writeFileSync(`${OUT}${name}.webp`, Buffer.from(webp, 'base64'))
  console.log('saved', name)
}

async function open(role, route, theme, inset) {
  await fetch(`${BASE}/__reset`) // every pass starts from the same scene
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, timezoneId: 'Asia/Manila', locale: 'en-PH' })
  await ctx.addInitScript(shiftClock, NOW)
  // ThemeModeNotifier reads shared_preferences 'theme_mode' (1 = light, 2 = dark).
  await ctx.addInitScript((v) => localStorage.setItem('flutter.theme_mode', v), theme === 'dark' ? '2' : '1')
  const p = await ctx.newPage()
  await p.goto(`${BASE}/?as=${role}${inset ? '&inset=1' : ''}#${route}`)
  await p.waitForTimeout(8000)
  return { ctx, p }
}
const go = async (p, route) => {
  await p.evaluate((h) => (location.hash = h), route)
  await p.waitForTimeout(3500)
}

for (const theme of ['dark', 'light']) {
  // Full phone screens, laid out with iPhone safe areas.
  let { ctx, p } = await open('user', '/user/track', theme, true)
  await save(`track-${theme}`, await p.screenshot())
  await go(p, `/user/orders/${ids.live}/chat`)
  await save(`chat-${theme}`, await p.screenshot())
  await go(p, '/user/shop')
  await save(`shop-${theme}`, await p.screenshot())
  await ctx.close()
  // Vendor and admin home screens, for the About page.
  for (const role of ['vendor', 'admin']) {
    ;({ ctx, p } = await open(role, `/${role}`, theme, true))
    await save(`${role}-${theme}`, await p.screenshot())
    await ctx.close()
  }
}
await b.close()
