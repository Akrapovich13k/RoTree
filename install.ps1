# RoTree installer for Windows (PowerShell).
#
# Two modes, picked automatically:
#   1. Standalone .exe (no Node required) — preferred when a release exists.
#   2. Node bundle (~290 KB) — fallback when Node is present.
#
# Usage:
#   irm https://raw.githubusercontent.com/Akrapovich13k/RoTree/main/install.ps1 | iex
#
# Overrides:
#   $env:ROTREE_INSTALL_DIR="$env:USERPROFILE\bin"
#   $env:ROTREE_BRANCH="develop"           # bundle mode only
#   $env:ROTREE_VERSION="v0.1.0"           # pin a release tag
#   $env:ROTREE_MODE="binary|bundle|auto"  # default: auto

$ErrorActionPreference = "Stop"

$Repo    = if ($env:ROTREE_REPO)    { $env:ROTREE_REPO }    else { "Akrapovich13k/RoTree" }
$Branch  = if ($env:ROTREE_BRANCH)  { $env:ROTREE_BRANCH }  else { "main" }
$Mode    = if ($env:ROTREE_MODE)    { $env:ROTREE_MODE }    else { "auto" }
$Version = if ($env:ROTREE_VERSION) { $env:ROTREE_VERSION } else { "latest" }
$InstallDir = if ($env:ROTREE_INSTALL_DIR) {
    $env:ROTREE_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "rotree\bin"
}

function Write-Step($msg)  { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  OK $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "  !  $msg" -ForegroundColor Yellow }
function Fail($msg)        { Write-Host "  X  $msg" -ForegroundColor Red; exit 1 }

Write-Host "RoTree installer" -ForegroundColor White
Write-Host ""

# Detect Node
$HasNode = $false
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        $major = [int]($nodeVersion -replace '^v(\d+)\..*', '$1')
        if ($major -ge 18) { $HasNode = $true }
    }
} catch { }

# Decide mode
$UseBinary = $false
switch ($Mode) {
    "binary" { $UseBinary = $true }
    "bundle" { $UseBinary = $false }
    default {
        # auto: prefer binary unless Node is already installed
        $UseBinary = -not $HasNode
    }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

function Resolve-ReleaseTag {
    if ($Version -ne "latest") { return $Version }
    try {
        $resp = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest" `
            -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue
        $loc = $resp.Headers.Location
    } catch {
        # PowerShell follows redirects by default; the exception carries the redirect.
        $loc = $_.Exception.Response.Headers.Location.ToString()
    }
    if ($loc) {
        return ($loc -split "/")[-1]
    }
    return $null
}

function Install-Binary {
    $tag = Resolve-ReleaseTag
    if (-not $tag -or $tag -eq "releases") {
        Write-Warn2 "No published release found yet."
        return $false
    }
    $arch = "x64"
    if ([System.Environment]::Is64BitOperatingSystem -eq $false) {
        Write-Warn2 "Only 64-bit Windows is supported by the standalone binary."
        return $false
    }
    $url  = "https://github.com/$Repo/releases/download/$tag/rotree-windows-$arch.exe"
    $exe  = Join-Path $InstallDir "rotree.exe"
    Write-Step "downloading standalone binary $tag for windows-$arch"
    Write-Step "URL: $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
    } catch {
        Write-Warn2 "Binary download failed: $($_.Exception.Message)"
        return $false
    }
    $size = (Get-Item $exe).Length
    if ($size -lt 1000000) {
        Write-Warn2 "Downloaded file is suspiciously small ($size bytes)."
        Remove-Item $exe -ErrorAction SilentlyContinue
        return $false
    }
    Write-Ok "Installed $exe"
    return $true
}

function Install-Bundle {
    if (-not $HasNode) {
        Write-Host ""
        Write-Warn2 "Node.js 18+ is required for the bundle install path."
        Write-Host ""
        Write-Host "  Install Node:" -ForegroundColor White
        Write-Host "    https://nodejs.org/" -ForegroundColor Cyan
        Write-Host "    Or: winget install OpenJS.NodeJS.LTS" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Or skip Node entirely with the standalone .exe:" -ForegroundColor White
        Write-Host "    `$env:ROTREE_MODE='binary'; irm https://raw.githubusercontent.com/$Repo/main/install.ps1 | iex" -ForegroundColor Cyan
        Write-Host ""
        Fail "Re-run this script once Node.js is on your PATH."
    }
    Write-Ok "Node.js $nodeVersion detected."

    $SourceUrl = "https://raw.githubusercontent.com/$Repo/$Branch/cli/dist/rotree.js"
    $Js  = Join-Path $InstallDir "rotree.js"
    $Cmd = Join-Path $InstallDir "rotree.cmd"
    Write-Step "downloading JS bundle from $SourceUrl"
    try {
        Invoke-WebRequest -Uri $SourceUrl -OutFile $Js -UseBasicParsing
    } catch {
        Fail "Download failed from $SourceUrl"
    }
    $firstLine = (Get-Content $Js -TotalCount 1)
    if (-not ($firstLine -like "*node*")) {
        Fail "Downloaded file doesn't look right. Aborting."
    }
    @"
@echo off
node "%~dp0rotree.js" %*
"@ | Set-Content -Path $Cmd -Encoding ASCII
    Write-Ok "Installed JS bundle + rotree.cmd shim."
}

if ($UseBinary) {
    if (-not (Install-Binary)) {
        Install-Bundle
    }
} else {
    Install-Bundle
}

# Sanity-run
$exe = Join-Path $InstallDir "rotree.exe"
$cmd = Join-Path $InstallDir "rotree.cmd"
$run = if (Test-Path $exe) { $exe } else { $cmd }
try {
    $v = & $run version 2>$null
    Write-Ok "$v works."
} catch {
    Fail "Installed file failed to run."
}

# PATH check
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
}

Write-Host ""
Write-Host "Next:" -ForegroundColor White
Write-Host "  cd <your-roblox-project>"
Write-Host "  rotree mcp-install        # auto-configures Claude Code / Desktop"
Write-Host "  rotree mcp                # start the bridge + MCP server"
