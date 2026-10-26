/**
 * FinanceQuizWord brand mark — a folded-ribbon "F" with three ascending
 * financial bars on a navy-to-blue gradient tile (512x512 source art), using the
 * same palette as the main FinanceQuizWord site.
 * Ids are suffixed with useId() because the mark is rendered in both the
 * header and the footer, and duplicate ids would make the paint references
 * ambiguous for anything else on the page.
 */
import { useId } from 'react';

export default function Logo({ className = '' }) {
  const suffix = useId().replace(/[^a-zA-Z0-9]/g, '');
  const id = {
    bg: `ffLogoBg${suffix}`,
    ribbon: `ffLogoRibbon${suffix}`,
    highlight: `ffLogoHighlight${suffix}`,
    accent: `ffLogoAccent${suffix}`,
    shadow: `ffLogoShadow${suffix}`,
  };

  return (
    <svg className={className} viewBox="0 0 512 512" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={id.bg} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#3B82F6" />
          <stop offset="0.55" stopColor="#1E3A8A" />
          <stop offset="1" stopColor="#0B1F4D" />
        </linearGradient>
        <linearGradient id={id.ribbon} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#DBEAFE" />
          <stop offset="1" stopColor="#60A5FA" />
        </linearGradient>
        <linearGradient id={id.highlight} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#FFFFFF" />
          <stop offset="1" stopColor="#BFDBFE" />
        </linearGradient>
        <linearGradient id={id.accent} x1="0" y1="0" x2="0.8" y2="1">
          <stop offset="0" stopColor="#67E8F9" />
          <stop offset="1" stopColor="#00D4FF" />
        </linearGradient>
        <filter id={id.shadow} x="-20%" y="-20%" width="140%" height="150%">
          <feDropShadow dx="0" dy="7" stdDeviation="7" floodColor="#0B1F4D" floodOpacity="0.45" />
        </filter>
      </defs>
      <rect x="28" y="28" width="456" height="456" rx="76" fill={`url(#${id.bg})`} />
      <g filter={`url(#${id.shadow})`}>
        {/* folded ribbon F */}
        <path
          d="M153 367V192c0-58 39-97 98-97h111c-15 31-39 47-77 47h-52c-28 0-43 17-43 43v24h108c-13 27-34 42-67 42h-41v116c0 28-15 43-43 43-27 0-43-15-43-43Z"
          fill={`url(#${id.ribbon})`}
        />
        <path
          d="M153 209c0-31 15-52 43-66 15-8 34-11 56-11h110c-15 30-39 46-77 46h-52c-28 0-43 17-43 43v20h-37Z"
          fill="#60A5FA"
          opacity="0.92"
        />
        <path
          d="M153 367V258h37v109c0 28-15 43-43 43-12 0-22-3-29-10 22-2 35-13 35-33Z"
          fill={`url(#${id.highlight})`}
        />
        {/* ascending financial bars */}
        <rect x="221" y="321" width="43" height="76" rx="13" fill={`url(#${id.highlight})`} />
        <rect x="278" y="286" width="43" height="111" rx="13" fill={`url(#${id.ribbon})`} />
        <rect x="335" y="244" width="43" height="153" rx="13" fill={`url(#${id.accent})`} />
      </g>
    </svg>
  );
}
