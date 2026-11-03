import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { execSync } from 'node:child_process'
import { BRAND } from './src/config/brand.js'

// A short build stamp shown at the bottom of every page, so it is easy to tell which
// version a browser is really running. RENDER_GIT_COMMIT is set by Render during builds.
function buildStamp() {
  let sha = (process.env.RENDER_GIT_COMMIT || process.env.GITHUB_SHA || '').slice(0, 7)
  if (!sha) {
    try {
      sha = execSync('git rev-parse --short HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim()
    } catch {
      sha = 'dev'
    }
  }
  return `${sha} · ${new Date().toISOString().slice(0, 10)}`
}

// Search-engine files that need the site's address. The address comes from VITE_SITE_URL (set it to the final
// domain in the host's environment settings) or, on Render, from RENDER_EXTERNAL_URL. Without an address the
// absolute-URL tags (canonical, share image, sitemap) are left out instead of pointing somewhere wrong.
function seo() {
  const raw = (process.env.VITE_SITE_URL || process.env.RENDER_EXTERNAL_URL || '').trim().replace(/\/+$/, '')
  const site = /^https?:\/\/[^\s/]+$/i.test(raw) ? raw : ''
  const description = BRAND.description
  const graph = [
    { '@type': 'Organization', '@id': site ? `${site}/#org` : undefined, name: BRAND.name, url: site || undefined, logo: site ? `${site}/icon-512.png` : undefined },
    { '@type': 'WebSite', name: BRAND.appTitle, url: site ? `${site}/` : undefined, inLanguage: 'en', publisher: site ? { '@id': `${site}/#org` } : undefined },
    { '@type': 'WebApplication', name: BRAND.appTitle, description, applicationCategory: 'BusinessApplication', operatingSystem: 'Any', url: site ? `${site}/` : undefined, image: site ? `${site}/og-image.png` : undefined, author: { '@type': 'Organization', name: BRAND.name } },
  ]
  // Every %BRAND_...% token in index.html comes from src/config/brand.js.
  const esc = (t) => String(t).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')
  const tokens = {
    BRAND_NAME: BRAND.name,
    BRAND_SHORT_NAME: BRAND.shortName,
    BRAND_APP_TITLE: BRAND.appTitle,
    BRAND_PRODUCT: BRAND.product,
    BRAND_DESCRIPTION: BRAND.description,
    BRAND_SHARE_LINE: BRAND.shareLine,
    BRAND_SEARCH_SUMMARY: BRAND.landing.searchSummary,
    BRAND_HEADLINE: `${BRAND.landing.headline.join(' ')} ${BRAND.landing.headlineEmphasis}`,
    BRAND_SLUG: BRAND.slug,
    BRAND_THEME_DARK: BRAND.themeColor.dark,
    BRAND_THEME_LIGHT: BRAND.themeColor.light,
  }
  const manifest = JSON.stringify({
    name: BRAND.appTitle,
    short_name: BRAND.shortName,
    description: BRAND.shareLine,
    start_url: '/',
    scope: '/',
    display: 'standalone',
    background_color: BRAND.themeColor.light,
    theme_color: BRAND.accent,
    icons: [
      { src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/favicon.svg', sizes: 'any', type: 'image/svg+xml' },
    ],
  }, null, 2)
  return {
    name: 'brand-and-seo',
    configureServer(server) {
      server.middlewares.use('/manifest.webmanifest', (_req, res) => {
        res.setHeader('Content-Type', 'application/manifest+json')
        res.end(manifest)
      })
    },
    transformIndexHtml(html) {
      const jsonLd = JSON.stringify({ '@context': 'https://schema.org', '@graph': graph }).replaceAll('<', '\\u003c')
      let out = html
      for (const [key, value] of Object.entries(tokens)) out = out.replaceAll(`%${key}%`, esc(value))
      return out
        .replace(/<!--site-->([\s\S]*?)<!--\/site-->/g, site ? '$1' : '')
        .replaceAll('%SITE_URL%', site)
        .replace('<!--json-ld-->', `<script type="application/ld+json">${jsonLd}</script>`)
    },
    generateBundle() {
      this.emitFile({ type: 'asset', fileName: 'manifest.webmanifest', source: manifest + '\n' })
      // The sign-in / password pages are for people, not for search results.
      const robots = ['User-agent: *', 'Allow: /', 'Disallow: /set-password', ...(site ? [`Sitemap: ${site}/sitemap.xml`] : []), '']
      this.emitFile({ type: 'asset', fileName: 'robots.txt', source: robots.join('\n') })
      if (site) {
        const lastmod = new Date().toISOString().slice(0, 10)
        this.emitFile({
          type: 'asset',
          fileName: 'sitemap.xml',
          source: `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>${site}/</loc><lastmod>${lastmod}</lastmod><changefreq>monthly</changefreq><priority>1.0</priority></url>\n</urlset>\n`,
        })
      }
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), seo()],
  define: { __BUILD_STAMP__: JSON.stringify(buildStamp()) },
  build: {
    rolldownOptions: {
      output: {
        // Keep the three dashboards (and their tabs) out of the first download: the landing page and the sign-in page
        // only need the libraries and the small shared pieces; a signed-in person fetches the dashboard code next.
        codeSplitting: {
          groups: [
            { name: 'vendor', test: /node_modules/, priority: 20 },
            { name: 'core', test: /src[\\/](components|hooks|lib|services)[\\/]/, priority: 15 },
            { name: 'dashboards', test: /src[\\/]views[\\/](?!Landing|Login|SetPassword)/, priority: 10 },
          ],
        },
      },
    },
  },
})
