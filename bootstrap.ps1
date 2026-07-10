#Requires -Version 5.1
<#
    bootstrap.ps1 — Windows half of the dotfiles.

    Run from a WINDOWS clone of this repo (e.g. C:\dev\dotfiles):
        pwsh -File .\bootstrap.ps1        # PowerShell 7
        powershell -File .\bootstrap.ps1  # Windows PowerShell 5.1

    Links the cross-platform pieces into their Windows locations:
      - Neovim config  -> %LOCALAPPDATA%\nvim   (directory junction, no admin)
      - PowerShell profile -> $PROFILE.CurrentUserAllHosts

    Idempotent: re-running relinks and backs up any real files it replaces.
    For live-updating file links, enable Windows Developer Mode
    (Settings > Privacy & security > For developers). Otherwise the profile
    is copied instead of symlinked and won't auto-update on `git pull`.
#>

$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($m) { Write-Host "`n===> $m" -ForegroundColor Cyan }
function Write-Info($m) { Write-Host ":: $m" }

# Link a directory via junction (works without admin / Developer Mode).
function Link-Dir([string]$Target, [string]$Link) {
    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.LinkType) {
            Remove-Item $Link -Force
        } else {
            $backup = "$Link.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Write-Info "Backing up existing $Link -> $backup"
            Move-Item $Link $backup
        }
    }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Info "Linked (junction): $Link -> $Target"
}

# Link a file via symlink; fall back to a copy if symlinks aren't permitted.
function Link-File([string]$Target, [string]$Link) {
    $dir = Split-Path -Parent $Link
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $Link) { Remove-Item $Link -Force }
    try {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
        Write-Info "Linked (symlink): $Link -> $Target"
    } catch {
        Copy-Item $Target $Link -Force
        Write-Info "Symlink not permitted (enable Developer Mode) — copied instead: $Link"
    }
}

Write-Host "Dotfiles — Windows setup"
Write-Info "Repo: $RepoDir"

# 1. Neovim configuration
Write-Step "Neovim configuration"
$nvimTarget = Join-Path $RepoDir 'nvim\.config\nvim'
if (Test-Path $nvimTarget) {
    Link-Dir $nvimTarget (Join-Path $env:LOCALAPPDATA 'nvim')
    Write-Info "Plugins install on first launch: run  nvim"
} else {
    Write-Info "Warning: nvim config not found at $nvimTarget"
}

# 2. PowerShell profile
Write-Step "PowerShell profile"
$profileTarget = Join-Path $RepoDir 'powershell\Microsoft.PowerShell_profile.ps1'
if (Test-Path $profileTarget) {
    Link-File $profileTarget $PROFILE.CurrentUserAllHosts
} else {
    Write-Info "Warning: profile not found at $profileTarget"
}

# 3. Optional: nudge for native tools that the profile/aliases assume
Write-Step "Recommended native tools (optional)"
foreach ($t in 'nvim','eza','git') {
    if (Get-Command $t -ErrorAction SilentlyContinue) {
        Write-Info "found: $t"
    } else {
        Write-Info "missing: $t  (winget install ...)  — some aliases need it"
    }
}

Write-Step "Done"
Write-Info "Restart your terminal, or reload now:  . `$PROFILE"
