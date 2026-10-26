# Builds the PNG brand assets from src/assets/brand/logo-financequizword.svg.
#
# The supplied SVG is a 512x512 canvas that wraps a single 1254x1254 PNG, which
# makes the file ~1.7 MB — far too heavy for a 40 px letter mark or a favicon.
# It is kept as the source of truth (outside public/, so it is never deployed)
# and this script decodes the embedded raster once and downsamples it.
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$svgPath = Join-Path $root 'src\assets\brand\logo-financequizword.svg'
$imageDir = Join-Path $root 'public\images'

$svg = Get-Content -Raw -LiteralPath $svgPath
$match = [regex]::Match($svg, 'base64,([A-Za-z0-9+/=]+)')
if (-not $match.Success) { throw "No embedded image found in $svgPath" }

$bytes = [Convert]::FromBase64String($match.Groups[1].Value)
$stream = New-Object System.IO.MemoryStream (,$bytes)
$source = [System.Drawing.Image]::FromStream($stream)

$targets = @(
  # 128 px covers the 40 px header mark and the 52 px splash on 2-3x screens.
  @{ File = (Join-Path $imageDir 'logo-financequizword.png'); Size = 128 }
  @{ File = (Join-Path $root 'public\favicon.png');           Size = 64 }
)

try {
  foreach ($target in $targets) {
    $bitmap = New-Object System.Drawing.Bitmap($target.Size, $target.Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.DrawImage($source, 0, 0, $target.Size, $target.Size)
    }
    finally {
      $graphics.Dispose()
    }

    $bitmap.Save($target.File, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $length = (Get-Item -LiteralPath $target.File).Length
    Write-Host ("{0}  {1}x{1}  {2:N0} bytes" -f $target.File, $target.Size, $length)
  }
}
finally {
  $source.Dispose()
  $stream.Dispose()
}
