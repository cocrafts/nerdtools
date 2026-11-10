# Agent hook for the Herdr app mod "agent-resume" (Windows, PowerShell 5.1 or 7).
#
# It writes the session of a coding agent on its herdr-core terminal as labels:
#   resume.agent   = the agent: claude or agy
#   resume.session = the session id
#   resume.pid     = the pid of the shell that runs the agent now
#   resume.args    = the flags of the agent command (for example --dangerously-skip-permissions)
#   resume.tried   = (removed) the mark of an earlier resume attempt
# After a reboot, herdr-core gives the terminal a new shell with a new pid.
# The mod sees the different pid and types the resume command of the agent in the shell.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File <this file> <agent> <start|end>
#   Claude Code: SessionStart -> "claude start", SessionEnd -> "claude end"
#   Antigravity: SessionStart -> "agy start"
# OpenCode uses its own TUI plugin (herdr-agent-resume-opencode.js).
# Codex has no hook: Codex runs its hooks in a shared background daemon, which has the
# environment of the terminal that started the daemon, not of the terminal of the session.
# The mod reads the Codex session files (~/.codex/sessions) instead.

param([string]$Agent = "", [string]$Action = "")

# The agents. proc: the process name or the script path of the agent.
# oneShot: flags or subcommands of a run with no interactive session (never recorded).
# drop: session flags that the mod adds again (with their value, if they have one).
# values: flags that take a separate value, kept with that value.
$Agents = @{
    claude = @{
        proc    = '^claude(\.exe)?$'
        script  = '[\\/]@anthropic-ai[\\/]claude-code[\\/]'
        oneShot = @('-p', '--print')
        drop    = @('--resume', '-r', '--continue', '-c', '--session-id', '--fork-session', '--from-pr')
        values  = @('--model', '--permission-mode', '--effort', '--agent', '--settings', '--add-dir', '--mcp-config', '--fallback-model')
    }
    agy = @{
        proc    = '^agy(\.exe)?$'
        script  = $null
        oneShot = @('-p', '--print', '--prompt')
        drop    = @('-c', '--continue', '--conversation')
        values  = @('--model', '--mode', '--effort', '--agent', '--project', '--settings', '--add-dir', '--log-file')
    }
}

$def = $Agents[$Agent]
if ($null -eq $def) { exit 0 }

# Only terminals of herdr-core have this variable.
$terminal = $env:HC_TERMINAL_ID
if ([string]::IsNullOrWhiteSpace($terminal)) { exit 0 }

# The hc program of herdr-core: from the PATH, else from the folder of the Windows
# installer (%LOCALAPPDATA%\Programs\herdr-core), which the installer does not add to the PATH.
$hc = Get-Command hc -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if (-not $hc -and $env:LOCALAPPDATA) {
    $installed = Join-Path $env:LOCALAPPDATA 'Programs\herdr-core\hc.exe'
    if (Test-Path -LiteralPath $installed) { $hc = $installed }
}
if (-not $hc) { exit 0 }

# Read the hook input as UTF-8 bytes.
$reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
$text = $reader.ReadToEnd()
try {
    $payload = if ([string]::IsNullOrWhiteSpace($text)) { $null } else { $text | ConvertFrom-Json }
} catch {
    exit 0
}
if ($null -eq $payload) { exit 0 }

# Claude: snake_case. Antigravity: camelCase.
$sessionId = @($payload.session_id, $payload.sessionId, $payload.conversationId) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($sessionId)) { exit 0 }
if ($sessionId -notmatch '^[A-Za-z0-9_-]+$') { exit 0 }

# Sub-agents share the terminal of the main session. Do not record them.
if (-not [string]::IsNullOrWhiteSpace($payload.agent_id)) { exit 0 }

# The command line of the agent process above this hook.
function Get-AgentCommandLine {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 10 -and $null -ne $proc; $i++) {
        if ($proc.Name -match $def.proc) { return $proc.CommandLine }
        if ($def.script -and $proc.CommandLine -match $def.script) { return $proc.CommandLine }
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.ParentProcessId)" -ErrorAction SilentlyContinue
    }
    return $null
}

# The arguments after the agent program (skips "node" and the script path of a node install).
function Get-AgentArguments([string]$commandLine) {
    $tokens = @([regex]::Matches($commandLine, '"[^"]*"|\S+') | ForEach-Object { $_.Value.Trim('"') })
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $leaf = Split-Path $tokens[$i] -Leaf
        if ($leaf -match $def.proc -or ($def.script -and $tokens[$i] -match $def.script)) {
            return @($tokens | Select-Object -Skip ($i + 1))
        }
    }
    return @($tokens | Select-Object -Skip 1)
}

# Keep the flags that change how the agent runs. Drop the session flags and any prompt text.
function Get-ResumeArgs([string[]]$tokens) {
    $keep = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $tok = $tokens[$i]
        $name = ($tok -split '=', 2)[0]
        $next = if ($i + 1 -lt $tokens.Count) { $tokens[$i + 1] } else { $null }
        if ($def.drop -contains $name) {
            # Skip the value of a session flag (for example --resume <id>).
            if ($tok -notmatch '=' -and $null -ne $next -and $next -notmatch '^-') { $i++ }
            continue
        }
        if ($def.values -contains $tok -and $null -ne $next) {
            if ($next -match '^[\w.:/\\=-]+$') { $keep.Add($tok); $keep.Add($next) }
            $i++
            continue
        }
        if ($tok -match '^--?[A-Za-z][\w-]*(=[\w.:/\\-]+)?$') { $keep.Add($tok) }
    }
    return ($keep -join ' ')
}

try {
    $info = & $hc get $terminal --json 2>$null | ConvertFrom-Json
} catch {
    exit 0
}
if ($null -eq $info) { exit 0 }

if ($Action -eq "start") {
    $commandLine = Get-AgentCommandLine
    if ($null -eq $commandLine) { exit 0 }
    $tokens = Get-AgentArguments $commandLine
    # A one-shot run (claude -p, agy -p) is often a script or another agent. Do not record it.
    # A one-shot flag counts anywhere. A one-shot word counts only as the first word that is not a flag.
    $firstWord = $null
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $tok = $tokens[$i]
        if ($tok -match '^-') {
            if ($def.oneShot -contains (($tok -split '=', 2)[0])) { exit 0 }
            if ($def.values -contains $tok) { $i++ }
            continue
        }
        if ($null -eq $firstWord) { $firstWord = $tok }
    }
    if ($null -ne $firstWord -and $def.oneShot -contains $firstWord) { exit 0 }
    $resumeArgs = Get-ResumeArgs $tokens
    & $hc label $terminal "resume.agent=$Agent" "resume.session=$sessionId" "resume.pid=$($info.pid)" "resume.args=$resumeArgs" "resume.tried=" 2>$null | Out-Null
    exit 0
}

if ($Action -eq "end") {
    # Claude Code only. Remove the labels only when the person exits the agent.
    # "other" can be a Windows shutdown: keep the labels for the resume.
    # "clear" starts a new session: the next SessionStart replaces the labels.
    $reason = "$($payload.reason)"
    if ($reason -ne "prompt_input_exit" -and $reason -ne "logout") { exit 0 }
    if ($info.labels.'resume.session' -ne $sessionId) { exit 0 }
    & $hc label $terminal "resume.agent=" "resume.session=" "resume.pid=" "resume.args=" "resume.tried=" 2>$null | Out-Null
    exit 0
}
