<#
.SYNOPSIS
  Renders public\images\og\og-default.png (1200x675 social preview card).

.DESCRIPTION
  The default Open Graph image carries the brand: the deep-navy canvas with soft
  blue glows from the main FinanceQuizWord site are drawn with GDI+, while the
  logo itself is rasterised from public\favicon.svg (the single source of truth
  for the mark) using headless Edge, so the card can never drift away from the
  logo used in the header.

  Run it again whenever the brand name, tagline, palette or logo changes:

      powershell -ExecutionPolicy Bypass -File ./scripts/make-og-default.ps1
#>

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$outFile = Join-Path $root 'public\images\og\og-default.png'
$logoSvg = Join-Path $root 'public\favicon.svg'

$brandName = 'Finance'
$brandTail = 'QuizWord'
$tagline = 'Clear, practical money education'

$w = 1200
$h = 675

# --- Rasterise the logo SVG (transparent 512x512 PNG) ---------------------------
$edgeCandidates = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)
$edge = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) {
  throw 'Microsoft Edge was not found — it is used to rasterise favicon.svg into the OG card.'
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ff-og-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$logoPng = Join-Path $workDir 'logo.png'

try {
  # A plain file path breaks when the repo lives in a folder with spaces,
  # so hand Edge a properly escaped file:// URI.
  $logoSvgUri = ([System.Uri]$logoSvg).AbsoluteUri
  $edgeArgs = @(
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
    "--user-data-dir=$workDir\edge-profile",
    '--window-size=512,512', '--default-background-color=00000000',
    '--virtual-time-budget=2000',
    "--screenshot=$logoPng",
    $logoSvgUri
  )
  Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -NoNewWindow

  # Edge can hand back control a moment before the PNG lands on disk.
  for ($i = 0; $i -lt 20 -and -not (Test-Path $logoPng); $i++) { Start-Sleep -Milliseconds 250 }
  if (-not (Test-Path $logoPng)) { throw "Edge did not produce $logoPng" }

  # --- Draw the card ------------------------------------------------------------
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  # Base: the main site's navy canvas.
  $g.Clear([System.Drawing.Color]::FromArgb(15, 23, 42))

  # Soft radial blue glows, matching the body background of the main site.
  function Add-Glow {
    param($graphics, [int]$cx, [int]$cy, [int]$r, [System.Drawing.Color]$color)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($cx - $r, $cy - $r, $r * 2, $r * 2)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterColor = $color
    $brush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
    $graphics.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
  }

  Add-Glow $g 120 135 520 ([System.Drawing.Color]::FromArgb(110, 30, 58, 138))
  Add-Glow $g 1080 200 560 ([System.Drawing.Color]::FromArgb(90, 37, 99, 235))
  Add-Glow $g 600 560 520 ([System.Drawing.Color]::FromArgb(70, 30, 64, 175))

  # Faint dot grid for texture.
  $dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24, 96, 165, 250))
  for ($dy = 0; $dy -lt $h; $dy += 28) {
    for ($dx = 0; $dx -lt $w; $dx += 28) {
      $g.FillEllipse($dotBrush, $dx, $dy, 3.2, 3.2)
    }
  }
  $dotBrush.Dispose()

  # Logo: the SVG art has ~5.5% transparent padding, so the box is larger than the
  # visible tile (168 * 0.89 = 150).
  $markSize = 168
  $markX = ($w - $markSize) / 2
  $markY = 139
  $logo = [System.Drawing.Image]::FromFile($logoPng)
  $g.DrawImage($logo, [single]$markX, [single]$markY, [single]$markSize, [single]$markSize)
  $logo.Dispose()

  # Wordmark: "Finance" in white, "QuizWord" in the main site's light blue — joined, no space.
  $titleFont = New-Object System.Drawing.Font('Segoe UI', 88, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $nameSize = $g.MeasureString($brandName, $titleFont)
  $tailSize = $g.MeasureString($brandTail, $titleFont)
  $fullNameSize = $g.MeasureString($brandName + $brandTail, $titleFont)
  # MeasureString adds one trailing-space advance; removing it keeps the wordmark joined.
  $trailing = $nameSize.Width + $tailSize.Width - $fullNameSize.Width
  $titleY = 340
  $titleX = ($w - ($fullNameSize.Width - $trailing)) / 2

  $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $blueBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(96, 165, 250))
  $g.DrawString($brandName, $titleFont, $whiteBrush, [single]$titleX, [single]$titleY)
  $g.DrawString($brandTail, $titleFont, $blueBrush, [single]($titleX + $fullNameSize.Width - $tailSize.Width), [single]$titleY)

  $tagFont = New-Object System.Drawing.Font('Segoe UI', 34, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $tagBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(214, 156, 163, 175))
  $tagSize = $g.MeasureString($tagline, $tagFont)
  $g.DrawString($tagline, $tagFont, $tagBrush, [single](($w - $tagSize.Width) / 2 + 8), [single]($titleY + $nameSize.Height + 6))

  $whiteBrush.Dispose()
  $blueBrush.Dispose()
  $tagBrush.Dispose()
  $g.Dispose()
  $bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
finally {
  Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Wrote $((Resolve-Path $outFile))" -ForegroundColor Green
