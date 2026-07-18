#Requires -Version 5.1
<#
    bootstrap.ps1 - Windows half of the dotfiles.

    Run from a WINDOWS clone of this repo (e.g. C:\dev\dotfiles):
        pwsh -File .\bootstrap.ps1        # PowerShell 7
        powershell -File .\bootstrap.ps1  # Windows PowerShell 5.1

    Links the cross-platform pieces into their Windows locations:
      - Neovim config  -> %LOCALAPPDATA%\nvim   (directory junction)
      - PowerShell profile: a stub at $PROFILE that dot-sources the repo profile
      - Obsidian config -> <vault>\.obsidian    (directory junction, per vault)
      - Repos: clones/updates CJ's repos into C:\dev over SSH
        (mirrors bootstrap.sh's repo setup on the Linux side)

    Windows counterpart of setup_obsidian() in bootstrap.sh. Pass -Vaults to
    override the default vault list.

    NO ADMIN OR DEVELOPER MODE REQUIRED. Directory junctions and the profile
    stub both work for a plain user; edits still flow through on `git pull`.
    Everything it touches lives under your Windows user home (%LOCALAPPDATA%,
    %USERPROFILE%). Idempotent: re-running is safe and backs up real files it
    replaces. (On a truly locked box where even junctions are blocked, the
    nvim config is copied instead - works, but won't live-update.)
#>

param(
    # Vaults to link the Obsidian config into. Windows equivalent of the
    # vaults list in bootstrap.sh's setup_obsidian(). Missing ones are skipped.
    [string[]]$Vaults = @('C:\dev\zettlepara', 'C:\dev\ai-chats')
)

$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($m) { Write-Host "`n===> $m" -ForegroundColor Cyan }
function Write-Info($m) { Write-Host ":: $m" }

# Link a directory via junction (works without admin / Developer Mode).
function Link-Dir([string]$Target, [string]$Link) {
    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.LinkType) {
            # Delete the reparse point only. Remove-Item -Force would see the
            # target's children through the link, demand -Recurse, and (if given
            # it) delete the target's contents.
            [System.IO.Directory]::Delete($Link, $false)
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
        Write-Info "Junction failed - copied instead (won't live-update): $Link"
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
# Managed by dotfiles bootstrap.ps1 - do not edit; edit the repo profile instead.
# Sources the versioned PowerShell profile so `git pull` updates flow through.
`$__dotfilesProfile = '$Target'
if (Test-Path `$__dotfilesProfile) { . `$__dotfilesProfile }
"@
    Set-Content -Path $ProfilePath -Value $stub -Encoding UTF8
    Write-Info "Wrote profile stub -> sources $Target"
}

Write-Host "Dotfiles - Windows setup"
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

# 2. PowerShell profile (stub that sources the repo file - no admin needed)
# Written to BOTH editions: PowerShell 7 and Windows PowerShell 5.1 use
# different profile paths, so cover both regardless of which one runs bootstrap.
Write-Step "PowerShell profile"
$profileTarget = Join-Path $RepoDir 'powershell\Microsoft.PowerShell_profile.ps1'
if (Test-Path $profileTarget) {
    $docs = [Environment]::GetFolderPath('MyDocuments')   # respects OneDrive redirection
    $profilePaths = @(
        (Join-Path $docs 'PowerShell\profile.ps1'),         # PowerShell 7+
        (Join-Path $docs 'WindowsPowerShell\profile.ps1')   # Windows PowerShell 5.1
    )
    foreach ($pp in $profilePaths) { Set-ProfileStub $profileTarget $pp }
} else {
    Write-Info "Warning: profile not found at $profileTarget"
}

# 3. Obsidian configuration (junctioned into each vault that exists)
Write-Step "Obsidian configuration"
$obsidianTarget = Join-Path $RepoDir 'obsidian\.obsidian'
if (Test-Path $obsidianTarget) {
    $linked = 0
    foreach ($vault in $Vaults) {
        if (Test-Path $vault) {
            Link-Dir $obsidianTarget (Join-Path $vault '.obsidian')
            $linked++
        } else {
            Write-Info "skipped (no such vault): $vault"
        }
    }
    if ($linked -gt 0) {
        Write-Info "Plugins install from the community browser on first launch (see community-plugins.json)"
    }
} else {
    Write-Info "Warning: obsidian config not found at $obsidianTarget"
}

# 4. Repos (mirrors bootstrap.sh's repo setup; Windows repos live in C:\dev)
$DevDir = 'C:\dev'

# Check we can reach a repo (e.g. private repos need SSH access).
function Test-RepoAccess([string]$Url) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # PS5.1 throws on redirected native stderr under 'Stop'
    git ls-remote $Url 2>&1 | Out-Null
    $ok = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $old
    return $ok
}

# Clone if missing, pull if already there.
function Get-Repo([string]$Url, [string]$Dest) {
    if (Test-Path (Join-Path $Dest '.git')) {
        Write-Info "Updating $Dest"
        git -C $Dest pull --rebase
    } elseif (Test-RepoAccess $Url) {
        git clone $Url $Dest
    } else {
        Write-Info "Warning: no access to $Url (private repo / no SSH key?) - skipping"
    }
}

Write-Step "Repos ($DevDir)"
if (Get-Command git -ErrorAction SilentlyContinue) {
    if (-not (Test-Path $DevDir)) { New-Item -ItemType Directory -Path $DevDir -Force | Out-Null }
    Get-Repo 'git@github.com:cjnowacek/bash.git' (Join-Path $DevDir 'bash')
    Get-Repo 'git@github.com:cjnowacek/mcp-chat-logger.git' (Join-Path $DevDir 'mcp-chat-logger')
    foreach ($name in 'zettelpara', 'ai-chats') {
        $answer = Read-Host ":: Clone $name? [y/N]"
        if ($answer -match '^[Yy]$') {
            Get-Repo "git@github.com:cjnowacek/$name.git" (Join-Path $DevDir $name)
        } else {
            Write-Info "Skipping $name"
        }
    }
} else {
    Write-Info "git not found - skipping repo setup"
}

# 5. Optional: nudge for native tools that the profile/aliases assume
Write-Step "Recommended native tools (optional)"
foreach ($t in 'nvim','eza','git') {
    if (Get-Command $t -ErrorAction SilentlyContinue) {
        Write-Info "found: $t"
    } else {
        Write-Info "missing: $t  (winget install ...)  - some aliases need it"
    }
}

Write-Step "Done"
Write-Info "Restart your terminal, or reload now:  . `$PROFILE"
