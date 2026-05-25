# RoTree installer for Windows (PowerShell).
#
# Usage:
#   irm https://raw.githubusercontent.com/Akrapovich13k/RoTree/main/install.ps1 | iex
#
# Override the install dir or branch:
#   $env:ROTREE_INSTALL_DIR="$env:USERPROFILE\bin"; irm ... | iex
#   $env:ROTREE_BRANCH="develop"; irm ... | iex

$ErrorActionPreference = "Stop"

$Repo   = if ($env:ROTREE_REPO)   { $env:ROTREE_REPO }   else { "Akrapovich13k/RoTree" }
$Branch = if ($env:ROTREE_BRANCH) { $env:ROTREE_BRANCH } else { "main" }
$InstallDir = if ($env:ROTREE_INSTALL_DIR) {
    $env:ROTREE_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "rotree\bin"
}
$SourceUrl = "https://raw.githubusercontent.com/$Repo/$Branch/cli/dist/rotree.js"

function Write-Step($msg) { Write-Host "  → $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "  ! $msg" -ForegroundColor Yellow }
function Fail($msg)       { Write-Host "  ✗ $msg" -ForegroundColor Red; exit 1 }

Write-Host "RoTree installer" -ForegroundColor White
Write-Host ""

# 1. Check Node.js
try {
    $nodeVersion = node --version 2>$null
    if (-not $nodeVersion) { throw }
} catch {
    Fail "Node.js 18+ is required but was not found. Install it: https://nodejs.org"
}
$major = [int]($nodeVersion -replace '^v(\d+)\..*', '$1')
if ($major -lt 18) {
    Fail "Node.js 18+ is required (you have $nodeVersion)."
}
Write-Ok "Node.js $nodeVersion detected."

# 2. Create install dir
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$Js  = Join-Path $InstallDir "rotree.js"
$Cmd = Join-Path $InstallDir "rotree.cmd"

Write-Step "Installing to $InstallDir"

# 3. Download bundled CLI
try {
    Invoke-WebRequest -Uri $SourceUrl -OutFile $Js -UseBasicParsing
} catch {
    Fail "Download failed from $SourceUrl"
}

# Sanity check
$firstLine = (Get-Content $Js -TotalCount 1)
if (-not ($firstLine -like "*node*")) {
    Fail "Downloaded file doesn't look right. Aborting."
}
Write-Ok "Downloaded."

# 4. Write a .cmd shim so `rotree` works on Windows shells
@"
@echo off
node "%~dp0rotree.js" %*
"@ | Set-Content -Path $Cmd -Encoding ASCII

Write-Ok "Created rotree.cmd shim."

# 5. Sanity-run
$version = & node $Js version 2>$null
if ($LASTEXITCODE -ne 0) {
    Fail "Installed file failed to run."
}
Write-Ok "$version works."

# 6. PATH check
$pathEntries = $env:Path -split ';'
if ($pathEntries -notcontains $InstallDir) {
    Write-Host ""
    Write-Warn2 "$InstallDir is NOT on your PATH yet."
    Write-Host ""
    Write-Host "Add it permanently (user-level) with this PowerShell command:" -ForegroundColor White
    Write-Host "  [Environment]::SetEnvironmentVariable('Path', `"`$([Environment]::GetEnvironmentVariable('Path','User'));$InstallDir`", 'User')"
    Write-Host ""
    Write-Host "Then restart your shell." -ForegroundColor White
} else {
    Write-Ok "$InstallDir is on your PATH."
    Write-Host ""
    Write-Host "Try it:" -ForegroundColor White
    Write-Host "  rotree help"
    Write-Host "  rotree serve"
}
