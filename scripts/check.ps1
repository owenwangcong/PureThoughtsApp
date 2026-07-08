# 质量门:一条命令跑完全部检查(PLAN P0.8)
# 用法: powershell -File scripts\check.ps1
# 内容: flutter analyze + flutter test + supabase pgTAP(本地栈未运行则跳过)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$fail = $false

Write-Host "== flutter analyze ==" -ForegroundColor Cyan
Push-Location (Join-Path $root 'app')
flutter analyze
if ($LASTEXITCODE -ne 0) { $fail = $true }

Write-Host "`n== flutter test ==" -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { $fail = $true }
Pop-Location

Write-Host "`n== supabase pgTAP ==" -ForegroundColor Cyan
Push-Location $root
npx supabase status *> $null
if ($LASTEXITCODE -eq 0) {
    npx supabase test db
    if ($LASTEXITCODE -ne 0) { $fail = $true }
} else {
    Write-Host "本地 Supabase 栈未运行,跳过 pgTAP(npx supabase start 后重跑)" -ForegroundColor Yellow
}
Pop-Location

if ($fail) {
    Write-Host "`n[FAIL] 存在未通过的检查" -ForegroundColor Red
    exit 1
}
Write-Host "`n[PASS] 全部通过" -ForegroundColor Green
exit 0
