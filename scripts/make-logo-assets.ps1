# Builds the PNG brand assets from src/assets/brand/logo-financequizword.svg.
#
# That SVG is not vector art: it is a 512x512 canvas holding a rounded
# gradient tile (<rect rx="80">, #152655 -> #121F42) with a 1254x1254 PNG
# stamped on top — ~1.7 MB, far too heavy for a 40 px mark or a favicon.
#
# The site uses the artwork only, no tile: this script decodes the embedded
# raster, crops it to a square around its opaque pixels and downsamples it
# while keeping full alpha, so the mark sits directly on the page background.
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$svgPath = Join-Path $root 'src\assets\brand\logo-financequizword.svg'
$imageDir = Join-Path $root 'public\images'

# Alpha at or below this counts as background when trimming faint edge noise.
$alphaThreshold = 8

$svg = Get-Content -Raw -LiteralPath $svgPath
$match = [regex]::Match($svg, 'base64,([A-Za-z0-9+/=]+)')
if (-not $match.Success) { throw "No embedded image found in $svgPath" }

function New-TransparentBitmap([int]$size) {
  $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  # Without this clear a fresh 32bpp bitmap is opaque black, which re-bakes the
  # very tile we are trying to drop.
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Get-OpaqueBounds([System.Drawing.Bitmap]$bitmap) {
  $rect = New-Object System.Drawing.Rectangle 0, 0, $bitmap.Width, $bitmap.Height
  $data = $bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rowBytes = [Math]::Abs($data.Stride)
  $buffer = New-Object byte[] ($rowBytes * $bitmap.Height)
  try {
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buffer, 0, $buffer.Length)
  } finally {
    $bitmap.UnlockBits($data)
  }
  $minX = $bitmap.Width; $minY = $bitmap.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $bitmap.Height; $y++) {
    $rowOffset = $y * $rowBytes
    for ($x = 0; $x -lt $bitmap.Width; $x++) {
      if ($buffer[$rowOffset + $x * 4 + 3] -gt $alphaThreshold) {
        if ($x -lt $minX) { $minX = $x }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  if ($maxX -lt 0) { throw 'Artwork is fully transparent.' }
  # Square crop centred on the artwork: cropping to the tight box instead would
  # stretch it, because every destination below is square.
  $side = [Math]::Max($maxX - $minX + 1, $maxY - $minY + 1)
  $x = [Math]::Min([Math]::Max(0, [int][Math]::Floor(($minX + $maxX + 1 - $side) / 2)), $bitmap.Width - $side)
  $y = [Math]::Min([Math]::Max(0, [int][Math]::Floor(($minY + $maxY + 1 - $side) / 2)), $bitmap.Height - $side)
  return New-Object System.Drawing.Rectangle $x, $y, $side, $side
}

$bytes = [Convert]::FromBase64String($match.Groups[1].Value)
$stream = New-Object System.IO.MemoryStream (, $bytes)
$decoded = [System.Drawing.Image]::FromStream($stream)
$source = New-Object System.Drawing.Bitmap $decoded
try {
  $bounds = Get-OpaqueBounds $source
  "opaque square: $($bounds.Width)x$($bounds.Height) at ($($bounds.X),$($bounds.Y)) of $($source.Width)"

  $targets = @(
    # 128 px covers the 40 px header mark and the 52 px splash on 2-3x screens.
    @{ File = (Join-Path $imageDir 'logo-financequizword.png'); Size = 128 }
    @{ File = (Join-Path $root 'public\favicon.png');           Size = 64 }
  )

  foreach ($target in $targets) {
    # Crop once with Clone so every later draw is a whole-image scale and needs
    # no source rectangle.
    $current = $source.Clone($bounds, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      # Halve down to near the target first, then one final bicubic pass:
      # noticeably cleaner than a single 10x reduction.
      while ([Math]::Floor($current.Width / 2) -ge $target.Size) {
        $half = [Math]::Floor($current.Width / 2)
        $step = New-TransparentBitmap $half
        $step.Graphics.DrawImage($current, 0, 0, $half, $half)
        $step.Graphics.Dispose()
        $current.Dispose()
        $current = $step.Bitmap
      }
      $final = New-TransparentBitmap $target.Size
      $final.Graphics.DrawImage($current, 0, 0, $target.Size, $target.Size)
      $final.Bitmap.Save($target.File, [System.Drawing.Imaging.ImageFormat]::Png)
      $final.Graphics.Dispose()
      $final.Bitmap.Dispose()
    } finally {
      $current.Dispose()
    }
    $length = (Get-Item -LiteralPath $target.File).Length
    Write-Host ("{0}  {1}x{1}  {2:N0} bytes" -f $target.File, $target.Size, $length)
  }
} finally {
  $source.Dispose()
  $decoded.Dispose()
  $stream.Dispose()
}
