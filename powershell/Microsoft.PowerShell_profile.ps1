# Windows PowerShell profile — mirrors ~/.dotfiles/unix/.unix_aliases
# Managed by the dotfiles repo; linked into place by bootstrap.ps1.
# Linux/WSL aliases live in unix/.unix_aliases — keep the two in rough sync.

# --- Listing (eza if installed, else Get-ChildItem) ------------------------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ll { eza -al @args }                       # ls -alX
    function lt { eza -al --sort=modified @args }       # ls -ctalX
    function z  { eza -al @args }
} else {
    function ll { Get-ChildItem -Force @args }
    function lt { Get-ChildItem -Force @args | Sort-Object LastWriteTime }
    function z  { Get-ChildItem -Force @args }
}

# --- Core ------------------------------------------------------------------
function c  { Clear-Host }
function gs { git status @args }

# --- Editor (nvim) ---------------------------------------------------------
function v   { nvim @args }
function n   { nvim @args }
Set-Alias -Name vim -Value nvim -Option AllScope

# --- File manager (yazi) ---------------------------------------------------
# On exit, cd to yazi's last directory (the upstream-recommended wrapper).
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi @args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -ErrorAction SilentlyContinue
    if ($cwd -and $cwd -ne $PWD.Path) { Set-Location -LiteralPath $cwd }
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
}

# --- Python ----------------------------------------------------------------
function p { python @args }

# --- Clipboard -------------------------------------------------------------
# NOTE: shadows PowerShell's built-in `copy` (alias for Copy-Item).
# Use Copy-Item / cp for copying files; `copy` here mirrors the WSL clipboard alias.
if (Test-Path Alias:copy) { Remove-Item Alias:copy -Force }
function copy { $input | Set-Clipboard }

# --- Run WSL bash tools from Windows ---------------------------------------
# sm -> your run-menu.sh inside WSL. Single quotes stop PowerShell from
# expanding ~, so WSL's bash does the tilde expansion instead.
function sm { wsl bash '~/dev/bash/run-menu.sh' @args }
# Generic passthrough:  wsltool rg "pattern" .   /   wsltool fd -e cs
function wsltool { wsl @args }

# --- Windows project shortcuts (edit to taste) -----------------------------
$Dev = 'C:\dev'
function titans { Set-Location (Join-Path $Dev 'titans-and-traitors') }

# --- zk notebook (parallels the export in zsh/bash rc) ---------------------
# Makes `zk daily|letter|work|sync` work from any directory.
$env:ZK_NOTEBOOK_DIR = Join-Path $Dev 'zettelpara'

# --- PATH: user-local bin (parallels ~/.local/bin) -------------------------
$LocalBin = Join-Path $HOME '.local\bin'
if ((Test-Path $LocalBin) -and ($env:Path -notlike "*$LocalBin*")) {
    $env:Path = "$env:Path;$LocalBin"
}
