/**
 * FinanceQuizWord brand mark — the logo artwork with no background tile.
 * Rendered from the transparent PNG built by scripts/make-logo-assets.ps1:
 * the supplied SVG paints a rounded navy gradient rect behind the same art and
 * ships a 1.7 MB raster, so the tile is dropped and the alpha is kept.
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
