# 商店截图去 alpha(第二步,必跑)
#
# App Store 与 Google Play 都要求截图/宣传图**不带透明通道**:
#   Apple  — screenshots must be flattened, no transparency
#   Play   — JPEG or 24-bit PNG (no alpha);feature graphic 同样要求无 alpha
# Flutter golden 输出的是 RGBA,所以每次重新生成截图后要跑一次本脚本。
#
# 用法(在 app/ 目录下):
#   flutter test tool/screenshots/store_screenshots_test.dart --update-goldens
#   powershell -ExecutionPolicy Bypass -File tool/screenshots/flatten-png.ps1
#
# app-icon-512.png 例外:Play 的商店图标规格是 32-bit PNG(允许 alpha),保持原样。

Add-Type -AssemblyName System.Drawing

$root = Join-Path $PSScriptRoot "..\..\..\release\screenshots"
$root = (Resolve-Path $root).Path

$files = Get-ChildItem $root -Recurse -Filter *.png |
    Where-Object { $_.Name -ne 'app-icon-512.png' }

foreach ($f in $files) {
    $src = [System.Drawing.Image]::FromFile($f.FullName)
    $bmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $g.Dispose()
    $src.Dispose()

    $tmp = "$($f.FullName).tmp"
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Move-Item $tmp $f.FullName -Force
}

Write-Output "flattened $($files.Count) png files (alpha removed)"
