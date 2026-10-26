<#
.SYNOPSIS
  Recolors the background field of the 14 article illustrations to the
  FinanceQuizWord navy palette.

.DESCRIPTION
  Each public\images\og\<slug>.png illustration was drawn on its own flat
  background (deep green, olive, navy...). This script samples the background
  colour from the image corners, builds a mask of every pixel that belongs to
  that background family (the flat field, the two large translucent circles and
  the dot grid all share one hue), and remaps only those pixels onto a single
  navy ramp: #0B1226 -> #223F7D, keeping their relative brightness.

  Foreground artwork is left untouched, so a credit gauge stays red/amber/green
  and coins stay gold while every card shares the site's navy backdrop.

  Safe to re-run: a background that is already navy maps onto the same ramp.
  Original files are tracked by git, so `git checkout -- public/images/og`
  restores them.

.EXAMPLE
  npm run og:recolor
  powershell -ExecutionPolicy Bypass -File .\scripts\recolor-og.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root 'public\images\og'

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class OgBackground
{
    // Navy ramp: darkest field to lightest circle.
    const int R0 = 11, G0 = 18, B0 = 38;    // #0B1226
    const int R1 = 34, G1 = 63, B1 = 125;   // #223F7D

    static void ToHsl(int r, int g, int b, out double h, out double s, out double l)
    {
        double rn = r / 255.0, gn = g / 255.0, bn = b / 255.0;
        double max = Math.Max(rn, Math.Max(gn, bn));
        double min = Math.Min(rn, Math.Min(gn, bn));
        double d = max - min;
        l = (max + min) / 2.0;
        if (d < 0.0001) { h = 0; s = 0; return; }
        s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
        if (max == rn) h = ((gn - bn) / d + (gn < bn ? 6 : 0)) * 60.0;
        else if (max == gn) h = ((bn - rn) / d + 2) * 60.0;
        else h = ((rn - gn) / d + 4) * 60.0;
    }

    static double HueDistance(double a, double b)
    {
        double d = Math.Abs(a - b) % 360.0;
        return d > 180.0 ? 360.0 - d : d;
    }

    /// Recolors one illustration in place, returning "skip" when the file has no
    /// coloured background to map.
    public static string Run(string sourcePath)
    {
        int w, h, rowBytes;
        byte[] buf;

        // Every pixel is read into memory first: GDI+ keeps the file locked until
        // the Bitmap is disposed, and it will not overwrite a file it has open.
        using (var src = new Bitmap(sourcePath))
        {
            w = src.Width; h = src.Height;
            rowBytes = w * 4;
            buf = new byte[rowBytes * h];

            using (var canvas = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(canvas)) g.DrawImageUnscaled(src, 0, 0);

                var area = new Rectangle(0, 0, w, h);
                var data = canvas.LockBits(area, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                try
                {
                    int stride = Math.Abs(data.Stride);
                    for (int y = 0; y < h; y++)
                    {
                        Marshal.Copy(IntPtr.Add(data.Scan0, y * stride), buf, y * rowBytes, rowBytes);
                    }
                }
                finally
                {
                    canvas.UnlockBits(data);
                }
            }
        }

        if (!Recolor(buf, w, h, rowBytes)) return "skip";

        var writeArea = new Rectangle(0, 0, w, h);
        using (var output = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            var data = output.LockBits(writeArea, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            try
            {
                int stride = Math.Abs(data.Stride);
                for (int y = 0; y < h; y++)
                {
                    Marshal.Copy(buf, y * rowBytes, IntPtr.Add(data.Scan0, y * stride), rowBytes);
                }
            }
            finally
            {
                output.UnlockBits(data);
            }

            // Written beside the original, then copied over it.
            string temp = sourcePath + ".tmp.png";
            output.Save(temp, ImageFormat.Png);
            File.Copy(temp, sourcePath, true);
            File.Delete(temp);
        }

        return "ok";
    }

    static bool Recolor(byte[] buf, int w, int h, int stride)
    {
        // --- 1. estimate the background hue from the corners ---
        int[] xs = { 3, w - 4, 3, w - 4, w / 2 };
        int[] ys = { 3, 3, h - 4, h - 4, 3 };
        double hx = 0, hy = 0, satSum = 0, lumSum = 0;
        int samples = 0;

        for (int i = 0; i < xs.Length; i++)
        {
            int idx = ys[i] * stride + xs[i] * 4;
            double hh, ss, ll;
            ToHsl(buf[idx + 2], buf[idx + 1], buf[idx], out hh, out ss, out ll);
            if (ss < 0.06) continue;
            double a = hh * Math.PI / 180.0;
            hx += Math.Cos(a); hy += Math.Sin(a);
            satSum += ss; lumSum += ll; samples++;
        }

        if (samples == 0) return false;

        double bgHue = Math.Atan2(hy / samples, hx / samples) * 180.0 / Math.PI;
        if (bgHue < 0) bgHue += 360.0;
        double bgSat = satSum / samples;
        double bgLum = lumSum / samples;

        // --- 2. mask background pixels and find their brightness range ---
        bool[] masked = new bool[w * h];
        double minL = 1, maxL = 0;

        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                int idx = row + x * 4;
                double hh, ss, ll;
                ToHsl(buf[idx + 2], buf[idx + 1], buf[idx], out hh, out ss, out ll);
                if (ss < 0.07) continue;                        // white ink, paper, dot specks
                if (HueDistance(hh, bgHue) > 24) continue;      // clearly another colour
                if (Math.Abs(ss - bgSat) > 0.32) continue;      // far more or less saturated
                if (ll > bgLum + 0.55 || ll < bgLum - 0.55) continue;
                masked[y * w + x] = true;
                if (ll < minL) minL = ll;
                if (ll > maxL) maxL = ll;
            }
        }

        if (maxL - minL < 0.01) { minL = Math.Max(0, minL - 0.05); maxL = minL + 0.10; }

        // --- 3. remap only the masked pixels onto the navy ramp ---
        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                if (!masked[y * w + x]) continue;
                int idx = row + x * 4;
                double hh, ss, ll;
                ToHsl(buf[idx + 2], buf[idx + 1], buf[idx], out hh, out ss, out ll);
                double t = (ll - minL) / (maxL - minL);
                t = t < 0 ? 0 : (t > 1 ? 1 : t);
                buf[idx + 2] = (byte)Math.Round(R0 + (R1 - R0) * t);
                buf[idx + 1] = (byte)Math.Round(G0 + (G1 - G0) * t);
                buf[idx] = (byte)Math.Round(B0 + (B1 - B0) * t);
            }
        }

        return true;
    }
}
'@

$files = Get-ChildItem -Path $dir -Filter '*.png' | Where-Object { $_.Name -ne 'og-default.png' }

if (-not $files) { throw "No article illustrations found in $dir" }

foreach ($file in $files) {
  $status = [OgBackground]::Run($file.FullName)
  if ($status -eq 'skip') {
    Write-Host "SKIP  $($file.Name)  (no coloured background found)" -ForegroundColor DarkGray
  } else {
    Write-Host "OK    $($file.Name)" -ForegroundColor Green
  }
}

Write-Host ''
Write-Host "Recolored $($files.Count) illustrations to the navy palette." -ForegroundColor Cyan
