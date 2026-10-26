/**
 * FinanceQuizWord brand mark — the logo as designed: artwork on its rounded
 * navy tile. Rendered from the PNG built by scripts/make-logo-assets.ps1, which
 * repaints the supplied SVG's two layers (rx=80 gradient rect + inset artwork)
 * at icon size, since the original file ships a 1.7 MB raster.
 * Decorative: the link and the page headings already carry the name.
 */
const LOGO_SRC = '/images/logo-financequizword.png';

export default function Logo({ className = '' }) {
  return (
    <img
      className={className}
      src={LOGO_SRC}
      alt=""
      aria-hidden="true"
      width="40"
      height="40"
      draggable="false"
      decoding="async"
    />
  );
}
