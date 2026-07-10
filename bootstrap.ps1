#Requires -Version 5.1
<#
    bootstrap.ps1 — Windows half of the dotfiles.

    Run from a WINDOWS clone of this repo (e.g. C:\dev\dotfiles):
        pwsh -File .\bootstrap.ps1        # PowerShell 7
        powershell -File .\bootstrap.ps1  # Windows PowerShell 5.1

    Links the cross-platform pieces into their Windows locations:
      - Neovim config  -> %LOCALAPPDATA%\nvim   (directory junction)
      - PowerShell profile: a stub at $PROFILE that dot-sources the repo profile

    NO ADMIN OR DEVELOPER MODE REQUIRED. Directory junctions and the profile
    stub both work for a plain user; edits still flow through on `git pull`.
    Everything it touches lives under your Windows user home (%LOCALAPPDATA%,
    %USERPROFILE%). Idempotent: re-running is safe and backs up real files it
    replaces. (On a truly locked box where even junctions are blocked, the
    nvim config is copied instead — works, but won't live-update.)
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
    try {
        New-Item -ItemType Junction -Path $Link -Target $Target -ErrorAction Stop | Out-Null
        Write-Info "Linked (junction): $Link -> $Target"
    } catch {
        # Junctions need no admin, but on a truly locked box fall back to a copy.
        Write-Info "Junction failed — copied instead (won't live-update): $Link"
        Copy-Item $Target $Link -Recurse -Force
    }
}

# Point $PROFILE at the repo profile WITHOUT symlinks: write a tiny stub that
# dot-sources the versioned file. Needs no admin / Developer Mode, and edits
# still flow through on `git pull`. Works on locked-down machines.
function Set-ProfileStub([string]$Target, [string]$ProfilePath) {
    $dir = Split-Path -Parent $ProfilePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $ProfilePath) { Remove-Item $ProfilePath -Force }
    $stub = @"
# Managed by dotfiles bootstrap.ps1 — do not edit; edit the repo profile instead.
# Sources the versioned PowerShell profile so `git pull` updates flow through.
`$__dotfilesProfile = '$Target'
if (Test-Path `$__dotfilesProfile) { . `$__dotfilesProfile }
"@
    Set-Content -Path $ProfilePath -Value $stub -Encoding UTF8
    Write-Info "Wrote profile stub -> sources $Target"
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

# 2. PowerShell profile (stub that sources the repo file — no admin needed)
Write-Step "PowerShell profile"
$profileTarget = Join-Path $RepoDir 'powershell\Microsoft.PowerShell_profile.ps1'
if (Test-Path $profileTarget) {
    Set-ProfileStub $profileTarget $PROFILE.CurrentUserAllHosts
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
