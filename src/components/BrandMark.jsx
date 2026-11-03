import { BRAND, wordmarkParts } from '../config/brand';

// THE LOGO MARK. A placeholder: an infinity loop (a figure eight lying on its side) that stands for "continuous attendance".
// Replace it with your own mark: either swap the <path> for your SVG shapes, or render an <img> of your logo here.
// `LOOP_PATH` is one closed path in a 120 x 60 box. Besides the small logo, the landing-page artwork, the pointer
// cursor, the loader and the clock-in animation all draw and run along this same path. To change the artwork
// everywhere, change LOOP_PATH (any closed path in that box works); to remove the artwork, see TEMPLATE.md.
export const LOOP_PATH = 'M60 30 C73 12 102 10 102 30 C102 50 73 48 60 30 C47 12 18 10 18 30 C18 50 47 48 60 30 Z';

export default function BrandMark({ size = 18, stroke = 11, className = '', title }) {
  return (
    <svg
      className={`la-mark ${className}`}
      viewBox="0 0 120 60"
      width={size * 2}
      height={size}
      fill="none"
      role={title ? 'img' : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : 'true'}
      focusable="false"
    >
      <path d={LOOP_PATH} stroke="currentColor" strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/** The company name as a wordmark: first word plain, the rest in the accent colour (see src/config/brand.js). */
export function Wordmark({ name = BRAND.name }) {
  const [head, tail] = wordmarkParts(name);
  return tail ? <>{head} <span>{tail}</span></> : <>{head}</>;
}
