// =====================================================================
// THE ONE PLACE WHERE THE COMPANY'S IDENTITY LIVES
//
// Change the values below and the whole app follows: landing page, sign-in page, header, footer, page titles,
// search-engine tags, the web-app manifest and the sign-in prompt of fingerprint / Face ID (see TEMPLATE.md).
// This file is plain JavaScript with no imports, so the build (vite.config.js) reads it too.
//
// What is NOT here, because people set it inside the running app (Settings / Structure tabs) once the database
// is connected: the company name shown after sign-in, working hours, time zone, departments, job roles,
// company networks, public holidays, the office floor plan and every person's account.
// =====================================================================

const name = 'Your Company';

export const BRAND = {
  /** Company name: header, footer, sign-in page, landing page, page title. */
  name,
  /** Short name for phone home screens and tabs (about 12 characters). */
  shortName: 'Your Co.',
  /** What the product is called under the company name. */
  product: 'Employee Attendance System',
  /** Page title and share-card name: "{name} Attendance". */
  appTitle: `${name} Attendance`,
  /** One sentence for search engines and link previews. */
  description: `${name} Attendance: clock in and out, track working hours, book vacation and days off, and see the whole team's calendar in one place.`,
  /** One line for link previews on social networks. */
  shareLine: `Clock in and out, book time off and see the team calendar at ${name}.`,
  /** Prefix for browser-storage keys and window events (lowercase letters only). */
  slug: 'attendance',
  /** Colour of the phone's browser bar and of the installed web app (dark theme, light theme). Keep in sync with src/styles/brand.css. */
  themeColor: { dark: '#050B18', light: '#F2F2F3' },
  /** Accent colour of the installed web app (the phone's task switcher). Keep in sync with --accent in src/styles/brand.css. */
  accent: '#1558FF',
  /** Time zone used before the company's own one is loaded (the company sets its real time zone in Settings). */
  fallbackTimezone: 'UTC',

  /** The public landing page (signed-out visitors at "/"). */
  landing: {
    kicker: ['Employee attendance', 'Office or online', 'One shared calendar'],
    headline: ['Attendance that keeps', 'everyone'],
    headlineEmphasis: 'in the loop.',
    lede: `${name}’s attendance system. Clock in from the company or from home, book time off, and see who is in, who is away and who has a birthday.`,
    finePrint: `For the ${name} team. Your administrator creates your account.`,
    dayKicker: 'A day with us',
    /** Shown in search results for people who have JavaScript switched off (index.html). */
    searchSummary: `${name} Attendance is the employee attendance system of ${name}: clock in and out from the company or online, track working hours, book vacation, unpaid leave and days off, and see the team calendar with public holidays, birthdays and work anniversaries.`,
  },

  /** Examples shown inside empty form fields (profile editor). */
  placeholders: { country: 'e.g. United Kingdom', office: 'e.g. London HQ' },

  /**
   * Public-holiday packs offered as a one-click button in Settings. The database ships the Georgian pack
   * (public.add_georgian_holidays); it is OFF here because it only suits companies in Georgia. Custom holidays
   * can always be added by hand. To add another country, write a function like it in a migration.
   */
  holidayPacks: { georgia: false },
};

/** "Your Company" -> ["Your", "Company"]: the first word is drawn plain, the rest in the accent colour. */
export function wordmarkParts(text = BRAND.name) {
  const i = text.indexOf(' ');
  return i === -1 ? [text, ''] : [text.slice(0, i), text.slice(i + 1)];
}
