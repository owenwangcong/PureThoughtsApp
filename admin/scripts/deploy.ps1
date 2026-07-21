# 构建并发布管理后台静态站到 admin.pure-thoughts.com(PLAN P7.5)
# 用法:.\scripts\deploy.ps1  (在 admin/ 或任意目录均可)
param(
  [string]$KeyFile = "D:\Projects\PureThoughts\purethoughts.pem",
  [string]$Target  = "ubuntu@api.pure-thoughts.com",
  [string]$WebRoot = "/var/www/admin"
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

# 防呆:必须存在指向生产的 NEXT_PUBLIC_SUPABASE_URL,避免把本地栈地址烧进线上产物
$envFiles = @(".env.production.local", ".env.local") | Where-Object { Test-Path $_ }
$hasProd = $false
foreach ($f in $envFiles) {
  if (Select-String -Path $f -Pattern "NEXT_PUBLIC_SUPABASE_URL=.*pure-thoughts\.com" -Quiet) { $hasProd = $true }
}
if (-not $hasProd) {
  throw "未在 .env.production.local / .env.local 找到生产 NEXT_PUBLIC_SUPABASE_URL,中止(防止发布连本地栈的产物)"
}

npm run build
if ($LASTEXITCODE -ne 0) { throw "next build 失败" }

ssh -o BatchMode=yes -i $KeyFile $Target "rm -rf /tmp/admin-out-new"
if ($LASTEXITCODE -ne 0) { throw "ssh 连接失败(检查密钥/网络)" }
scp -o BatchMode=yes -i $KeyFile -r -q .\out "${Target}:/tmp/admin-out-new"
if ($LASTEXITCODE -ne 0) { throw "scp 上传失败" }
ssh -o BatchMode=yes -i $KeyFile $Target "rsync -a --delete /tmp/admin-out-new/ $WebRoot/ && rm -rf /tmp/admin-out-new"
if ($LASTEXITCODE -ne 0) { throw "rsync 替换失败" }

Write-Output "已发布:https://admin.pure-thoughts.com(记得强刷浏览器缓存 Ctrl+F5)"
