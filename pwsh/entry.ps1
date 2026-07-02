# NerdTools PowerShell profile — Windows port of zsh/entry.sh
# Dot-sourced from $PROFILE. Repo root is derived from this file's location,
# so it works whether the repo is cloned as ~/nerdtool or ~/nerdtools.

$NerdRoot = Split-Path $PSScriptRoot -Parent

# --- Encoding (UTF-8 everywhere) ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- PATH ---
$env:PATH = @(
    "$HOME\.local\bin",
    "$HOME\go\bin",
    "$HOME\.cargo\bin",
    "$NerdRoot\bin",
    $env:PATH
) -join ';'

# --- Env ---
$env:XDG_CONFIG_HOME = "$HOME\.config"
$env:STARSHIP_CONFIG = "$NerdRoot\conf\starship.toml"
$env:EDITOR          = "nvim"
$env:REACT_EDITOR    = "nvim"

# --- Aliases / functions (equivalent of the aliases in entry.sh) ---
function vide { neovide @args }
function nvim { $env:TERM = "wezterm"; & nvim.exe @args }   # call the exe directly, no recursion

# --- PSReadLine: autosuggest + history (replaces oh-my-zsh plugins) ---
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    try {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    } catch {
        # PSReadLine < 2.2 (e.g. Windows PowerShell 5.1) has no prediction
        try { Set-PSReadLineOption -PredictionSource History } catch {}
    }
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -AddToHistoryHandler {
        param($line)
        # HISTORY_IGNORE: skip noise commands
        return ($line -notmatch '^(clear|ls|cd|pwd|exit|history)\s*$')
    }
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# --- posh-git (git status in the prompt, if installed) ---
if (Get-Module -ListAvailable posh-git) { Import-Module posh-git }

# --- Tool init (starship / zoxide / mise) ---
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
if (Get-Command mise -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (mise activate pwsh | Out-String) })
}

# --- Per-machine override (counterpart of entry.sh's local.zsh) ---
# Not in the repo/Syncthing; holds per-machine env, secrets, work aliases.
$LocalOverride = "$HOME\.config\nerdtools\local.ps1"
if (Test-Path $LocalOverride) { . $LocalOverride }
