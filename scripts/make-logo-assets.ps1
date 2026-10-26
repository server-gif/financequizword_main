# Builds the PNG brand assets from src/assets/brand/logo-financequizword.svg.
#
# That SVG is not vector art — it is a 512x512 canvas with two layers:
#   <rect width="512" height="512" rx="80" fill="linear-gradient(#152655 -> #121F42)">
#   <rect x="46" y="46" width="420" height="420" fill="<1254x1254 PNG>"/>
# i.e. the rounded navy tile plus the artwork sitting 9% inside it. Shipping the
# SVG itself would cost ~1.7 MB for a 40 px mark, so this script repaints that
# exact composition into small PNGs instead.
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$svgPath = Join-Path $root 'src\assets\brand\logo-financequizword.svg'
$imageDir = Join-Path $root 'public\images'

# Geometry copied from the SVG.
$canvas = 512
$tileRadius = 80
$artOffset = 46
$artSize = 420
$tileTop = [System.Drawing.Color]::FromArgb(255, 0x15, 0x26, 0x55)
$tileBottom = [System.Drawing.Color]::FromArgb(255, 0x12, 0x1F, 0x42)

function New-ClearedBitmap([int]$size) {
  $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  # A fresh 32bpp bitmap is opaque black; clearing keeps the rounded corners
  # transparent instead of showing black notches.
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Add-RoundedRect([System.Drawing.Drawing2D.GraphicsPath]$path, [int]$size, [int]$radius) {
  $diameter = $radius * 2
  [void]$path.AddArc(0, 0, $diameter, $diameter, 180, 90)
  [void]$path.AddArc($size - $diameter, 0, $diameter, $diameter, 270, 90)
  [void]$path.AddArc($size - $diameter, $size - $diameter, $diameter, $diameter, 0, 90)
  [void]$path.AddArc(0, $size - $diameter, $diameter, $diameter, 90, 90)
  [void]$path.CloseFigure()
}

$svg = Get-Content -Raw -LiteralPath $svgPath
$match = [regex]::Match($svg, 'base64,([A-Za-z0-9+/=]+)')
if (-not $match.Success) { throw "No embedded image found in $svgPath" }

$bytes = [Convert]::FromBase64String($match.Groups[1].Value)
$stream = New-Object System.IO.MemoryStream (, $bytes)
$artwork = [System.Drawing.Image]::FromStream($stream)

# Render once at the SVG's own 512 canvas size, then downscale: the tile edges
# and the artwork both stay smooth at 40 px.
$plate = New-ClearedBitmap $canvas
try {
  $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
  Add-RoundedRect $tile $canvas $tileRadius
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Rectangle 0, 0, $canvas, $canvas), $tileTop, $tileBottom, 90)
  $plate.Graphics.FillPath($brush, $tile)
  # Whole raster into the inset square — the int overload avoids PowerShell
  # binding DrawImage to the Point[] signature.
  $plate.Graphics.DrawImage($artwork, $artOffset, $artOffset, $artSize, $artSize)
  $brush.Dispose()
  $tile.Dispose()

  $targets = @(
    # 128 px covers the 40 px header mark and the 52 px splash on 2-3x screens.
    @{ File = (Join-Path $imageDir 'logo-financequizword.png'); Size = 128 }
    @{ File = (Join-Path $root 'public\favicon.png');           Size = 64 }
  )

  foreach ($target in $targets) {
    $final = New-ClearedBitmap $target.Size
    $final.Graphics.DrawImage($plate.Bitmap, 0, 0, $target.Size, $target.Size)
    $final.Bitmap.Save($target.File, [System.Drawing.Imaging.ImageFormat]::Png)
    $final.Graphics.Dispose()
    $final.Bitmap.Dispose()
    $length = (Get-Item -LiteralPath $target.File).Length
    Write-Host ("{0}  {1}x{1}  {2:N0} bytes" -f $target.File, $target.Size, $length)
  }
} finally {
  $plate.Bitmap.Dispose()
  $plate.Graphics.Dispose()
  $artwork.Dispose()
  $stream.Dispose()
}
