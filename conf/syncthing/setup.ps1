#!/usr/bin/env pwsh
# Syncthing setup for one machine. Idempotent — safe to re-run any time.
#
# What it ensures on this machine:
#   1. syncthing installed (scoop)
#   2. config generated (first run)
#   3. daemon running (hidden)
#   4. folder <FolderId> at <Path>, send/receive, trashcan versioning (30d)
#   5. .stignore that syncs ONLY $SyncFiles (negations MUST come before the
#      catch-all — syncthing uses FIRST-match-wins, unlike gitignore)
#   6. scheduled task "Syncthing" at logon (hidden, via wscript wrapper)
#
# Identity (cert.pem/key.pem) and the index database stay machine-local on
# purpose: sharing them would clone the device ID and break the protocol.
# Pairing with the other machine is manual: exchange device IDs once.
[CmdletBinding()]
param(
    [string]$FolderId = "compiler-docs",
    [string]$Path = "$HOME\projects\compiler\docs",
    [string[]]$SyncFiles = @("NIM-REF.md")
)
$ErrorActionPreference = "Stop"

function Step($m) { Write-Host "==> $m" }

# --- 1. install --------------------------------------------------------------
if (-not (Get-Command syncthing -ErrorAction SilentlyContinue)) {
    Step "installing syncthing via scoop"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw "scoop not found — install scoop first, or syncthing manually"
    }
    scoop install syncthing
} else {
    Step "syncthing already installed"
}

# --- 2. config ---------------------------------------------------------------
$configs = @(
    "$env:LOCALAPPDATA\Syncthing\config.xml",
    "$HOME\scoop\persist\syncthing\config\config.xml"
)
$configXml = $configs | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $configXml) {
    Step "generating initial config"
    syncthing generate | Out-Null
    $configXml = $configs | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $configXml) { throw "config.xml not found after generate" }
} else {
    Step "config found: $configXml"
}
$home2 = Split-Path $configXml

# --- 3. daemon ---------------------------------------------------------------
if (-not (Get-Process syncthing -ErrorAction SilentlyContinue)) {
    Step "starting daemon (hidden)"
    Start-Process -WindowStyle Hidden -FilePath (Get-Command syncthing).Source -ArgumentList "--no-browser"
    Start-Sleep -Seconds 5
} else {
    Step "daemon already running"
}
$system = syncthing cli show system | ConvertFrom-Json
$deviceId = $system.myID

# --- 4. folder ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Path)) {
    throw "folder path does not exist: $Path"
}
$exists = $false
try { syncthing cli config folders $FolderId dump-json 2>$null | Out-Null; $exists = $true } catch { }
if (-not $exists) {
    Step "adding folder $FolderId -> $Path"
    syncthing cli config folders add --id $FolderId --label $FolderId --path $Path --type sendreceive
} else {
    Step "folder $FolderId already configured"
}
Step "ensuring trashcan versioning (30 days)"
syncthing cli config folders $FolderId versioning type set trashcan | Out-Null
syncthing cli config folders $FolderId versioning params set cleanoutDays 30 | Out-Null

# --- 5. .stignore ------------------------------------------------------------
# First pattern that matches wins: negations first, catch-all last.
$stignore = (@($SyncFiles | ForEach-Object { "!/$_" }) + @("*")) -join "`n"
$stignorePath = Join-Path $Path ".stignore"
if (-not (Test-Path $stignorePath) -or (Get-Content $stignorePath -Raw) -ne $stignore + "`n") {
    Step "writing $stignorePath"
    [System.IO.File]::WriteAllText($stignorePath, $stignore + "`n")
} else {
    Step ".stignore already correct"
}

# force a rescan so the ignore patterns apply immediately
$apikey = [regex]::Match((Get-Content $configXml -Raw), '<apikey>([^<]+)</apikey>').Groups[1].Value
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8384/rest/db/scan?folder=$FolderId" -Headers @{ "X-API-Key" = $apikey } | Out-Null
Start-Sleep -Seconds 3

# --- 6. autostart ------------------------------------------------------------
$vbs = Join-Path $home2 "start-syncthing.vbs"
if (-not (Test-Path $vbs)) {
    Step "writing $vbs"
    $shim = (Get-Command syncthing).Source
    Set-Content -LiteralPath $vbs -Value ('CreateObject("Wscript.Shell").Run """' + $shim + '"" --no-browser", 0, False') -Encoding ASCII
} else {
    Step "wscript wrapper already present"
}
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbs`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "Syncthing" -Action $action -Trigger $trigger -Settings $settings -Description "Syncthing daemon at logon (hidden)" -Force | Out-Null
Step "scheduled task 'Syncthing' registered"

# --- summary -----------------------------------------------------------------
Start-Sleep -Seconds 2
$status = Invoke-RestMethod -Uri "http://127.0.0.1:8384/rest/db/status?folder=$FolderId" -Headers @{ "X-API-Key" = $apikey }
Write-Host ""
Write-Host "DONE."
Write-Host "  device id : $deviceId   <- add this on the other machine"
Write-Host "  folder    : $FolderId ($($status.state), $($status.localFiles) file(s) tracked)"
