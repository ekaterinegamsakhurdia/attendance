# Making this template yours

This project is a **white-label** employee attendance system. The functionality is finished and tested; a new
company only needs its **look** (name, colours, logo, words) and, once the database is connected, to **enter its
own information inside the running app**. Nothing here refers to any other company.

There are two separate jobs.

## A. Look and feel (in the code, once)

| What | Where | Notes |
|---|---|---|
| Company name, short name, product name, page title, search / share text, landing-page wording | `src/config/brand.js` | The single source: header, footer, sign-in page, landing page, tab title, link previews, installed web-app name and the Face ID / fingerprint prompt follow it. |
| Colours (dark and light theme) and fonts | `src/styles/brand.css` | Palette tokens (`--primary`, `--bg-page`, …) plus the colour channels (`--primary-rgb`, `--tint-rgb`, …) behind every translucent colour. Keep `themeColor` and `accent` in `brand.js` in step. |
| Logo mark | `src/components/BrandMark.jsx` (`BrandMark`, `LOOP_PATH`) and `public/favicon.svg` | The placeholder is a plain loop. `LOOP_PATH` is also the line that the loading animation, the clock-in celebration and the cursor trail draw, so replacing it re-shapes all of them. A logo with a different shape: replace the `BrandMark` drawing and, if you like, `LOOP_PATH`. |
| Share image and home-screen icons | `public/og-image.png`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png` | Either drop in finished PNG files with the same names, or run `npm run brand:images` (needs `npm i -D playwright && npx playwright install chromium`): it redraws them from `brand.js` and `favicon.svg`. |
| Web address for search engines | `VITE_SITE_URL` in the host's environment settings | Adds the canonical address, share-image links and `sitemap.xml`. |
| Passkey name | Edge Function secret `COMPANY_NAME` | Shown by the phone when it asks for Face ID / fingerprint. |
| Holiday button for one country | `holidayPacks` in `brand.js` | The database ships a Georgian pack, off by default. Another country: add a function like `seed_georgian_holidays` in a migration and a button next to the existing one in `src/views/ceo/HolidaysCard.jsx`. |

A few blue gradients in `src/styles/app.css` are still written as hex values (`#1A5CFF`, `#0A3FE0`, `#2F6BFF`, `#3B9BFF`,
`#6db1ff`, `#9ccbff`). If you change the brand colour, search for them once and replace them with your colours.

Check the result with `npm run dev`, then `npm run lint && npm test && npm run build`.

## B. The company's information (in the app, after the database is connected)

None of this is in the code. The first administrator (the *developer* account) and the CEO enter it in the running app:

| What | Where in the app |
|---|---|
| Company name after sign-in, working hours, time zone | Settings → Company Settings |
| Departments, department heads, job roles | Settings → Departments / Structure |
| Allowed office networks, Face ID / fingerprint requirement | Settings → Company Networks / security |
| Public holidays | Settings → Public Holidays (add by hand; one-click pack only if enabled) |
| Leave allowances (vacation / unpaid / day off) | Settings → Company Settings (defaults), per person under Analytics |
| People and their accounts | Employees / Accounts → Add |
| Office floor plan | Developer → Office map → Edit floor plan (default: one open office for everybody, plus a room each for CEO 1 and CEO 2; departments created later appear in the open office until the developer gives them their own room) |

## C. Connecting the new database

1. Create a **new Supabase project** (never reuse another company's).
2. Link it and apply all migrations: `supabase link --project-ref YOUR-REF` then `supabase db push`.
   `20260101000000_base_schema.sql` creates the five base tables first, so an empty project works.
   The database starts completely empty: no departments, job roles, holidays or people.
3. Copy `.env.example` to `.env.local` and fill in the project URL and the publishable key.
4. Edge Functions: `supabase secrets set SITE_URL=https://the-company-site.example COMPANY_NAME="Company Name"`, then deploy `invite-employee`, `delete-employee`, `webauthn` and `change-email`.
5. Create the first developer: Authentication → Users → Add user, then run `supabase/tools/create_first_developer.sql` in the SQL editor with that email.
6. Sign in as that developer, enter part B, create the CEO account(s), and invite the team.
7. Deploy the front end (any static host; build command `npm run build`, publish directory `dist`; set `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_SITE_URL`).

Full details of the setup and the security model are in `README.md`.

## Keeping several companies apart

One copy of this project, one Supabase project, one hosting site **per company**. Branding is in the code, so each
company is its own repository (or branch) created from this template; fixes made to the template can be merged
into each copy.
