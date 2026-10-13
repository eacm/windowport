$ErrorActionPreference = 'SilentlyContinue'
$hostProcess = Get-Process WindowPort.Host | Select-Object -First 1
if (-not $hostProcess) { exit 0 }

$sessionId = $hostProcess.SessionId
$line = quser | Where-Object { ($_ -split '\s+') -contains "$sessionId" } | Select-Object -First 1
if ($line -and (($line -split '\s+') -contains 'Disc')) {
    & "$env:SystemRoot\System32\tscon.exe" $sessionId /dest:console
}
