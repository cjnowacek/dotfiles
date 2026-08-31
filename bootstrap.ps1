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

    Then winget-installs the native tools that config assumes: neovim, git,
    ripgrep, fd, eza, gcc (WinLibs, for treesitter), and the Claude Code CLI.
    Anything already on PATH is skipped, and a failed install warns rather
    than aborts.

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
    [string[]]$Vaults = @('C:\dev\zettelpara', 'C:\dev\ai-chats')
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

# Install a package via winget, skipping if the command is already on PATH.
# Windows counterpart of install_dependencies()/install_neovim() in bootstrap.sh.
# Never fatal: a failed optional tool should not abort the rest of bootstrap.
function Install-Pkg([string]$Cmd, [string]$Id, [string]$Why) {
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Info "already installed: $Cmd"
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Info "winget missing - install $Id by hand ($Why)"
        return
    }
    Write-Info "installing $Id ($Why)"
    try {
        winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            Write-Info "winget exit $LASTEXITCODE for $Id - check manually"
        }
        # winget edits the PERSISTED PATH; this process keeps the environment it
        # started with. Re-read it so later Install-Pkg calls (and anything else
        # below) can actually see what was just installed.
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path', 'User')
    } catch {
        Write-Info "install failed for ${Id}: $($_.Exception.Message)"
    }
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

# 5. Claude Code CLI (native install; the nvim claudecode plugin shells out to it)
Write-Step "Claude Code"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Info "claude already installed: $(claude --version)"
} else {
    try {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Write-Info "Claude Code installed - reopen the terminal so PATH picks it up"
    } catch {
        Write-Info "Claude Code install failed: $($_.Exception.Message)"
        Write-Info "Install manually:  irm https://claude.ai/install.ps1 | iex"
    }
}

# 6. Native tools the nvim config and the aliases assume
Write-Step "Native tools"
Install-Pkg 'nvim' 'Neovim.Neovim'            'the editor itself'
Install-Pkg 'git'  'Git.Git'                  'plugin fetching, and a real Bash for Claude Code'
Install-Pkg 'rg'   'BurntSushi.ripgrep.MSVC'  'Telescope live_grep'
Install-Pkg 'fd'   'sharkdp.fd'               'Telescope find_files'
Install-Pkg 'eza'  'eza-community.eza'        'ls aliases in the profile'
Install-Pkg 'yazi' 'sxyazi.yazi'              'file manager, same y muscle memory as Linux'
# nvim-treesitter compiles parsers and needs a real C compiler. Its `main`
# branch probes for cc/gcc specifically, so zig does NOT satisfy the check even
# though it can compile C. WinLibs is the gcc build treesitter itself suggests,
# and needs no Visual Studio install.
Install-Pkg 'gcc'  'BrechtSanders.WinLibs.POSIX.UCRT' 'nvim-treesitter parser compilation'

# 7. zk CLI (not on winget; fetch the latest GitHub release binary).
# The PowerShell profile sets ZK_NOTEBOOK_DIR, and the vault's CLAUDE.md
# documents the zk d/l/w workflow -- this makes that work on Windows too.
Write-Step "zk"
if (Get-Command zk -ErrorAction SilentlyContinue) {
    Write-Info "zk already installed: $(zk --version)"
} else {
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/zk-org/zk/releases/latest'
        $asset = $rel.assets | Where-Object { $_.name -like '*-windows-x86_64.tar.gz' } | Select-Object -First 1
        if (-not $asset) { throw "no windows-x86_64 asset in release $($rel.tag_name)" }
        $dest = Join-Path $env:LOCALAPPDATA 'Programs\zk'
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        $tmp = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $tmp
        tar -xzf $tmp -C $dest          # bsdtar ships with Windows 10+
        Remove-Item $tmp
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($userPath -notlike "*$dest*") {
            [Environment]::SetEnvironmentVariable('Path', "$userPath;$dest", 'User')
            Write-Info "added $dest to user PATH"
        }
        Write-Info "zk $($rel.tag_name) installed to $dest - reopen the terminal so PATH picks it up"
    } catch {
        Write-Info "zk install failed: $($_.Exception.Message)"
        Write-Info "Install manually: https://github.com/zk-org/zk/releases"
    }
}

Write-Step "Done"
Write-Info "Restart your terminal so PATH picks up anything just installed."
Write-Info "Then run  nvim  once: lazy.nvim bootstraps and installs every plugin."
Write-Info "Reload the profile in place with:  . `$PROFILE"
