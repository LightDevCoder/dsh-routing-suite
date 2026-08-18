# dsh-routing-suite 一键安装（Windows PowerShell 5.1+）
# 与 install.sh 行为对齐：依赖检查 → 注入器 Release 安装 → Router preset 安装（带备份）→ 验证
# 用法：powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$versionsPath = Join-Path $root 'versions.json'
if (-not (Test-Path $versionsPath)) {
  Write-Host "[error] 找不到 versions.json（$versionsPath）——版本锁文件缺失，无法继续" -ForegroundColor Red
  exit 1
}
$versions = Get-Content -Raw $versionsPath | ConvertFrom-Json
$injVersion = $versions.injector.version
$routerVersion = $versions.router.version

# DSH_HOME：优先尊重环境变量，否则 %USERPROFILE%\.dsh
if ($env:DSH_HOME -and $env:DSH_HOME.Trim()) { $dshHome = $env:DSH_HOME } else { $dshHome = Join-Path $HOME '.dsh' }
$profile = 'web'
if ($env:DSH_PROFILE) { $profile = $env:DSH_PROFILE }

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'

function Backup-Dir([string]$dir) {
  if (Test-Path $dir) {
    $bak = "$dir.bak.$ts"
    Move-Item $dir $bak
    Write-Host "旧版本已备份到: $bak" -ForegroundColor Yellow
  }
}

# ---- 依赖检查（不满足即停止，不做任何修改） ----
Write-Host "=== [1/4] 依赖检查 ===" -ForegroundColor Cyan
$missing = @()
foreach ($cmd in @('dsh','node','git','curl','tar','pnpm')) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { $missing += $cmd }
}
if ($missing.Count -gt 0) {
  Write-Host "缺少关键依赖，安装已停止（未做任何修改）：$($missing -join ', ')" -ForegroundColor Red
  Write-Host '  pnpm: 可执行 npm install -g pnpm，或 corepack enable pnpm'
  exit 1
}
Write-Host "DSH_HOME = $dshHome ; profile = $profile" -ForegroundColor Green

# ---- 注入器安装 ----
Write-Host "`n=== [2/4] 装配注入器 v$injVersion ===" -ForegroundColor Cyan
$injDir = Join-Path $dshHome 'local-plugins\dsh-super-injector'
$needInjector = $true
if (Test-Path (Join-Path $injDir '.version')) {
  $installed = (Get-Content (Join-Path $injDir '.version') -Raw).Trim()
  if ($installed -eq $injVersion) {
    Write-Host "注入器 v$injVersion 已安装（$injDir），跳过下载" -ForegroundColor Green
    $needInjector = $false
  }
}
if ($needInjector) {
  Backup-Dir $injDir
  $tmp = Join-Path $env:TEMP "dsh-injector-$ts"
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $tgz = Join-Path $tmp "dsh-external-dsh-super-injector-$injVersion.tgz"
  $url = "https://github.com/yjh051108/dsh-super-injector/releases/download/v$injVersion/dsh-external-dsh-super-injector-$injVersion.tgz"
  Write-Host "下载 Release 包：$url" -ForegroundColor Cyan
  Invoke-WebRequest -Uri $url -OutFile $tgz
  New-Item -ItemType Directory -Force -Path (Split-Path $injDir) | Out-Null
  New-Item -ItemType Directory -Force -Path $injDir | Out-Null
  tar -xzf $tgz -C $injDir --strip-components=1
  Remove-Item $tgz -Force
  if (-not (Test-Path (Join-Path $injDir 'lib\index.js'))) {
    Write-Host "[error] 注入器 Release 包内容不完整（缺少 lib/index.js）" -ForegroundColor Red
    exit 1
  }
  # 移除未就绪且会导致 DSH 设置页出现重复空白「插件」页的前端 client 声明
  $pkgPath = Join-Path $injDir 'package.json'
  if (Test-Path $pkgPath) {
    node -e '
      const fs = require("fs");
      const p = process.argv[1];
      const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
      if (pkg.dsh && pkg.dsh.client) {
        delete pkg.dsh.client;
        fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
      }
    ' "$pkgPath"
  }
  Set-Content -Path (Join-Path $injDir '.version') -Value $injVersion -NoNewline
  Write-Host "装配注入器到 profile '$profile' ..." -ForegroundColor Cyan
  & dsh plugin --profile $profile add $injDir
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[error] dsh plugin 装配注入器失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
    exit $LASTEXITCODE
  }
  Write-Host "注入器 v$injVersion 已装配进 $profile profile（重启 DSH 后生效）" -ForegroundColor Green
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
} else {
  # 检查已安装的 package.json 是否仍残留 client 声明（去除历史残留）
  $pkgPath = Join-Path $injDir 'package.json'
  if (Test-Path $pkgPath) {
    node -e '
      const fs = require("fs");
      const p = process.argv[1];
      const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
      if (pkg.dsh && pkg.dsh.client) {
        delete pkg.dsh.client;
        fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
      }
    ' "$pkgPath"
  }
}

# ---- Router presets 安装 ----
Write-Host "`n=== [3/4] 安装 Router Presets (Standard & Deep) v$routerVersion ===" -ForegroundColor Cyan
$routerStdDir = Join-Path $dshHome '.agent-presets\router-standard'
$routerDeepDir = Join-Path $dshHome '.agent-presets\router-deep'

# 判定源目录
$sm = Join-Path $root 'preset\preset'
$src = $null
$tmp = $null
if ((Test-Path (Join-Path $sm 'router-standard\preset.yml')) -and (Test-Path (Join-Path $sm 'router-spec\preset.yml'))) {
  $src = $sm
} else {
  $tmp = Join-Path $env:TEMP "dsh-router-$ts"
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $tgz = Join-Path $tmp "dsh-router-standard-$routerVersion.tgz"
  $url = "https://github.com/yjh051108/dsh-router-standard/releases/download/v$routerVersion/dsh-router-standard-$routerVersion.tgz"
  Write-Host "下载 Release 包（submodule 不可用）：$url" -ForegroundColor Cyan
  Invoke-WebRequest -Uri $url -OutFile $tgz
  tar -xzf $tgz -C $tmp --strip-components=1
  Remove-Item $tgz -Force
  $src = Join-Path $tmp 'preset'
}

function Install-Preset([string]$srcDir, [string]$targetDir, [string]$displayName, [string]$patchMode) {
  $need = $true
  if (Test-Path (Join-Path $targetDir '.version')) {
    $inst = (Get-Content (Join-Path $targetDir '.version') -Raw).Trim()
    if ($inst -eq $routerVersion) {
      Write-Host "$displayName v$routerVersion 已安装（$targetDir），跳过" -ForegroundColor Green
      $need = $false
    }
  }
  if ($need) {
    Backup-Dir $targetDir
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -Recurse -Force (Join-Path $srcDir '*') $targetDir
    if ($patchMode -eq 'deep') {
      $ymlPath = Join-Path $targetDir 'preset.yml'
      if (Test-Path $ymlPath) {
        $c = Get-Content -Raw $ymlPath
        $c = $c -replace 'name:\s*Router Spec', 'name: Router Deep'
        $c = $c -replace '\(spec\)', '(deep)'
        Set-Content -Path $ymlPath -Value $c
      }
    }
    foreach ($f in @('preset.yml','agent.cordis.yml','router-bootstrap.mjs','router-core.mjs')) {
      if (-not (Test-Path (Join-Path $targetDir $f))) {
        Write-Host "[error] $displayName 安装不完整（缺少 $f）" -ForegroundColor Red
        exit 1
      }
    }
    Set-Content -Path (Join-Path $targetDir '.version') -Value $routerVersion -NoNewline
    Write-Host "$displayName v$routerVersion 已安装（$targetDir）" -ForegroundColor Green
  }
}

# 1. 安装 router-standard
$stdSrc = Join-Path $src 'router-standard'
if (-not (Test-Path $stdSrc)) { $stdSrc = $src }
Install-Preset $stdSrc $routerStdDir "Router Standard" "standard"

# 2. 安装 router-deep
$specSrc = Join-Path $src 'router-spec'
if (Test-Path $specSrc) {
  Install-Preset $specSrc $routerDeepDir "Router Deep" "deep"
}

if ($tmp -and (Test-Path $tmp)) {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# ---- 验证 ----
Write-Host "`n=== [4/4] 验证 ===" -ForegroundColor Cyan
$rows = @(
  @('DSH CLI', (Get-Command dsh -ErrorAction SilentlyContinue) -ne $null),
  @('Injector files', (Test-Path (Join-Path $injDir 'lib\index.js'))),
  @('Router Standard', (Test-Path (Join-Path $routerStdDir 'preset.yml'))),
  @('Router Deep', (Test-Path (Join-Path $routerDeepDir 'preset.yml')))
)
$allOk = $true
foreach ($r in $rows) {
  if ($r[1]) { Write-Host ("{0,-22} OK" -f $r[0]) -ForegroundColor Green }
  else       { Write-Host ("{0,-22} FAIL" -f $r[0]) -ForegroundColor Red; $allOk = $false }
}
if ($allOk) {
  Write-Host "`nEnvironment ready." -ForegroundColor Green
} else {
  Write-Host "`nEnvironment NOT ready —— 存在失败项" -ForegroundColor Red
  exit 1
}

Write-Host "`n重启 DSH（web 服务）后，在新会话中验证："
Write-Host "  dev_plugin_status   -> dsh-super-injector active"
Write-Host "  dev_self_test       -> PASS"
Write-Host "  Preset 选择         -> Router Standard (experimental) 或 Router Deep (experimental)"
Write-Host "  dev_router_status   -> 对应 preset 正常显示"

