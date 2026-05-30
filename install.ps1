# dexter installer for Windows (PowerShell).
# Downloads the matching artifact from the latest GitHub Release and installs it.
#
# Usage:
#   irm https://raw.githubusercontent.com/OWNER/dexter/main/install.ps1 | iex
#
# Env overrides:
#   DEXTER_REPO     owner/repo         (default: OWNER/dexter)
#   DEXTER_VERSION  tag, e.g. v0.1.0   (default: latest release)

$ErrorActionPreference = 'Stop'

$Repo    = if ($env:DEXTER_REPO)    { $env:DEXTER_REPO }    else { 'OWNER/dexter' }
$Version = if ($env:DEXTER_VERSION) { $env:DEXTER_VERSION } else { 'latest' }
$App     = 'dexter'
$Asset   = 'dexter-windows-x64.zip'   # Flutter Windows desktop is x64 only

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Die($m)  { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

if ([Environment]::Is64BitOperatingSystem -eq $false) { Die 'x64 OS required' }

# --- resolve download URL --------------------------------------------------
$api = if ($Version -eq 'latest') {
  "https://api.github.com/repos/$Repo/releases/latest"
} else {
  "https://api.github.com/repos/$Repo/releases/tags/$Version"
}

Info "Querying $Repo ($Version)"
$headers = @{ 'User-Agent' = 'dexter-installer' }
$release = Invoke-RestMethod -Uri $api -Headers $headers
$url = ($release.assets | Where-Object { $_.name -eq $Asset }).browser_download_url
if (-not $url) { Die "asset '$Asset' not found in $Repo $Version" }

# --- download & install ----------------------------------------------------
$dest = Join-Path $env:LOCALAPPDATA "Programs\$App"
$tmp  = Join-Path $env:TEMP $Asset

Info "Downloading $Asset"
Invoke-WebRequest -Uri $url -OutFile $tmp -Headers $headers

Info "Installing to $dest"
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Expand-Archive -Path $tmp -DestinationPath $dest -Force
Remove-Item $tmp -Force

# --- add to user PATH ------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$dest*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$dest", 'User')
  Info "Added $dest to user PATH (restart shell to apply)"
}

Info "Done. Run: $App"
