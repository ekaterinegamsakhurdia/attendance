// Draws the picture files from src/config/brand.js and public/favicon.svg:
//   public/og-image.png        1200 x 630 share card (link previews)
//   public/icon-192.png, icon-512.png, apple-touch-icon.png   home-screen icons
//
// Run it after changing the name, the tagline or favicon.svg:   npm run brand:images
// It needs a browser once:   npx playwright install chromium   (and: npm i -D playwright)
// Prefer your own artwork? Skip this script and drop finished PNG files with the same names into public/.
import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { BRAND } from '../src/config/brand.js'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const pub = (f) => join(root, 'public', f)
const svg = readFileSync(pub('favicon.svg'), 'utf8')
const svgUrl = 'data:image/svg+xml;base64,' + Buffer.from(svg).toString('base64')
const esc = (t) => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;')

const { chromium } = await import('playwright').catch(() => {
  console.error('Playwright is not installed. Run:  npm i -D playwright && npx playwright install chromium')
  process.exit(1)
})
const browser = await chromium.launch()

async function shot(html, width, height, file, transparent = false) {
  const page = await browser.newPage({ viewport: { width, height } })
  await page.setContent(html)
  await page.screenshot({ path: pub(file), omitBackground: transparent })
  await page.close()
}

const icon = (size, pad) =>
  `<body style="margin:0;background:transparent"><img src="${svgUrl}" style="width:${size - pad * 2}px;height:${size - pad * 2}px;margin:${pad}px;display:block"></body>`
await shot(icon(192, 0), 192, 192, 'icon-192.png', true)
await shot(icon(512, 0), 512, 512, 'icon-512.png', true)
await shot(icon(180, 0), 180, 180, 'apple-touch-icon.png')

const headline = `${BRAND.landing.headline.join(' ')} <span style="color:${BRAND.accent}">${esc(BRAND.landing.headlineEmphasis)}</span>`
await shot(`<body style="margin:0;width:1200px;height:630px;box-sizing:border-box;padding:64px 72px;background:${BRAND.themeColor.light};
  font-family:Inter,Helvetica,Arial,sans-serif;color:#0A0A0B;display:flex;flex-direction:column;justify-content:space-between;
  background-image:linear-gradient(180deg,transparent 55%,${BRAND.accent} 130%)">
  <div style="display:flex;align-items:center;gap:16px;font-weight:700;font-size:30px"><img src="${svgUrl}" style="width:52px;height:52px">${esc(BRAND.name)}</div>
  <div style="font-weight:800;font-size:84px;line-height:1.02;letter-spacing:-3px;max-width:960px">${headline}</div>
  <div style="font-weight:700;font-size:30px;color:#fff;white-space:nowrap">${esc(BRAND.landing.kicker.join('. '))}.</div></body>`, 1200, 630, 'og-image.png')

await browser.close()
console.log('Wrote og-image.png, icon-192.png, icon-512.png and apple-touch-icon.png in public/')
