# toggle-suggest.ps1 -- switch autocomplete on/off for this workspace
#
# Usage (run inside tcl-practice):
#     powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1 status
#     powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1 off      # practice mode
#     powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1 on       # look-up-api mode
#     powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1          # toggle
#
# How it works: .vscode/settings.json (active) is swapped with one of
#   settings.off.json (autocomplete off) / settings.on.json (autocomplete on).
# VS Code reloads it automatically; no restart needed.
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads .ps1 as ANSI,
#       so non-ASCII text here breaks the parser.

param(
    [ValidateSet('toggle', 'on', 'off', 'status')]
    [string]$Mode = 'toggle'
)

$ErrorActionPreference = 'Stop'

$dir     = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '.vscode'
$active  = Join-Path $dir 'settings.json'
$offFile = Join-Path $dir 'settings.off.json'
$onFile  = Join-Path $dir 'settings.on.json'

foreach ($f in @($active, $offFile, $onFile)) {
    if (-not (Test-Path $f)) { throw "missing file: $f" }
}

function Get-State {
    $raw = Get-Content $active -Raw -Encoding utf8
    if ($raw -match '"editor\.suggestOnTriggerCharacters"\s*:\s*true')  { return 'on' }
    if ($raw -match '"editor\.suggestOnTriggerCharacters"\s*:\s*false') { return 'off' }
    return 'unknown'
}

function Show-State([string]$state) {
    switch ($state) {
        'on'      { Write-Host '[autocomplete: ON ]  triggers + parameter hints enabled' -ForegroundColor Green }
        'off'     { Write-Host '[autocomplete: OFF]  practice mode; press Ctrl+Space to ask once' -ForegroundColor Yellow }
        default   { Write-Host '[autocomplete: ?? ]  key not found in settings.json' -ForegroundColor DarkGray }
    }
}

if ($Mode -eq 'status') { Show-State (Get-State); exit 0 }

$current = Get-State
if ($Mode -eq 'toggle') {
    $target = if ($current -eq 'on') { 'off' } else { 'on' }
} else {
    $target = $Mode
}

if ($target -eq $current) {
    Show-State $current
    Write-Host 'already in this state; nothing to do.'
    exit 0
}

$source = if ($target -eq 'on') { $onFile } else { $offFile }
Copy-Item $source $active -Force

Show-State $target
Write-Host ("written: " + $active)
Write-Host 'VS Code picks it up automatically (no restart).'
