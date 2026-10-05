Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
$out = Join-Path $root "_icon_tmp"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function New-XIcon {
    param([int]$size, [bool]$rounded = $true)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $c1 = [System.Drawing.Color]::FromArgb(255, 99, 102, 241)
    $c2 = [System.Drawing.Color]::FromArgb(255, 139, 92, 246)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 45.0)

    if ($rounded) {
        $r = $size * 0.22
        $d = $r * 2
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc(0, 0, $d, $d, 180, 90)
        $path.AddArc($size - $d, 0, $d, $d, 270, 90)
        $path.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
        $path.AddArc(0, $size - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        $g.FillPath($brush, $path)
    } else {
        $g.FillRectangle($brush, $rect)
    }

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, ($size * 0.17))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $inset = $size * 0.27
    $g.DrawLine($pen, $inset, $inset, $size - $inset, $size - $inset)
    $g.DrawLine($pen, $size - $inset, $inset, $inset, $size - $inset)

    $g.Dispose()
    return $bmp
}

function Save-Scaled {
    param($srcBmp, [int]$size, [string]$path)
    $dst = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($srcBmp, 0, 0, $size, $size)
    $g.Dispose()
    $dst.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
}

# 512 master, rounded corners
$main = New-XIcon -size 512 -rounded $true

# linked sizes
Save-Scaled $main 96  (Join-Path $root "favicon-96x96.png")
Save-Scaled $main 32  (Join-Path $root "favicon-32x32.png")
Save-Scaled $main 16  (Join-Path $root "favicon-16x16.png")

# apple-touch-icon: full-bleed square (no transparency)
$apple = New-XIcon -size 512 -rounded $false
Save-Scaled $apple 180 (Join-Path $root "apple-touch-icon.png")
Save-Scaled $apple 192 (Join-Path $root "web-app-manifest-192x192.png")
$apple.Save((Join-Path $root "web-app-manifest-512x512.png"), [System.Drawing.Imaging.ImageFormat]::Png)

# favicon.ico: 16 + 32 + 48 packed
$p48 = Join-Path $out "favicon-48x48.png"
Save-Scaled $main 48 $p48
$pngs = @((Join-Path $root "favicon-16x16.png"), (Join-Path $root "favicon-32x32.png"), $p48)
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$pngs.Count)
$offset = 6 + 16 * $pngs.Count
foreach ($p in $pngs) {
    $bytes = [IO.File]::ReadAllBytes($p)
    $img = [System.Drawing.Image]::FromFile($p)
    $w = $img.Width; $h = $img.Height
    $img.Dispose()
    if ($w -ge 256) { $bw.Write([byte]0) } else { $bw.Write([byte]$w) }
    if ($h -ge 256) { $bw.Write([byte]0) } else { $bw.Write([byte]$h) }
    $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$bytes.Length)
    $bw.Write([uint32]$offset)
    $offset += $bytes.Length
}
foreach ($p in $pngs) { $bw.Write([IO.File]::ReadAllBytes($p)) }
$bw.Flush()
[IO.File]::WriteAllBytes((Join-Path $root "favicon.ico"), $ms.ToArray())
$bw.Dispose(); $ms.Dispose()

$main.Dispose(); $apple.Dispose()
Write-Output "DONE"
