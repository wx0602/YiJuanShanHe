param([switch]$Restart)

$ErrorActionPreference = 'Stop'
$healthUrl = 'http://127.0.0.1:8765/health'

$existing = $null
try {
    $existing = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
} catch {
    # No local service is listening yet.
}
if ($null -ne $existing) {
    if ($existing.configured -and -not $Restart) {
        Write-Output 'AI backend is already running on 127.0.0.1:8765.'
        exit 0
    }
    if (-not $existing.configured) {
        throw 'Port 8765 is occupied by an unconfigured backend. Stop it first.'
    }
}

$previousKey = $env:AI_UPSTREAM_API_KEY
if ([string]::IsNullOrWhiteSpace($previousKey)) {
    $secureKey = Read-Host 'Enter your newly issued DeepSeek API Key' -AsSecureString
    $env:AI_UPSTREAM_API_KEY = [System.Net.NetworkCredential]::new('', $secureKey).Password
    Remove-Variable secureKey
}
if ([string]::IsNullOrWhiteSpace($env:AI_UPSTREAM_API_KEY)) {
    throw 'No API key was entered. Backend was not started.'
}

try {
    $python = (Get-Command python -ErrorAction Stop).Source
    if ($Restart -and $null -ne $existing) {
        $listener = netstat -ano -p TCP | Where-Object {
            $_ -match '^\s*TCP\s+127\.0\.0\.1:8765\s+\S+\s+LISTENING\s+\d+\s*$'
        } | Select-Object -First 1
        if (-not $listener -or $listener -notmatch 'LISTENING\s+(\d+)\s*$') {
            throw 'Cannot identify the local backend process. It was left running.'
        }
        $serverPid = [int]$Matches[1]
        $oldProcess = Get-Process -Id $serverPid -ErrorAction Stop
        if ($oldProcess.ProcessName -notin @('python', 'pythonw')) {
            throw 'Port 8765 is not owned by Python. The existing process was left running.'
        }
        Stop-Process -Id $serverPid -Force
        Start-Sleep -Milliseconds 300
    }
    $backend = Start-Process -FilePath $python -ArgumentList 'server.py' `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 200
        if ($backend.HasExited) { break }
        try {
            $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
            if ($health.configured) { $ready = $true; break }
        } catch { }
    }
    if (-not $ready) {
        if (-not $backend.HasExited) { Stop-Process -Id $backend.Id -Force }
        throw 'Backend failed to start. Check Python and port 8765.'
    }
    Write-Output "AI backend started: PID $($backend.Id), http://127.0.0.1:8765"
} finally {
    if ([string]::IsNullOrEmpty($previousKey)) {
        Remove-Item Env:\AI_UPSTREAM_API_KEY -ErrorAction SilentlyContinue
    } else {
        $env:AI_UPSTREAM_API_KEY = $previousKey
    }
}
