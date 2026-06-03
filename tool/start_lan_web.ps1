param(
  [int]$RelayPort = 8080,
  [int]$WebPort = 8081,
  [switch]$OpenFirewall,
  [switch]$Stop,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $RepoRoot '.codex\logs'
$RelayLog = Join-Path $LogDir 'lan_web_relay.log'
$BuildLog = Join-Path $LogDir 'lan_web_build.log'
$WebLog = Join-Path $LogDir 'lan_web_static.log'

function Show-Help {
  Write-Host 'Usage:'
  Write-Host '  powershell -ExecutionPolicy Bypass -File tool\start_lan_web.ps1'
  Write-Host '  powershell -ExecutionPolicy Bypass -File tool\start_lan_web.ps1 -OpenFirewall'
  Write-Host '  powershell -ExecutionPolicy Bypass -File tool\start_lan_web.ps1 -Stop'
  Write-Host ''
  Write-Host 'Builds the Bussruta web app, then starts the WebSocket relay and static web server for same-network browser play.'
}

function Get-LanAddress {
  $addresses = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      $_.PrefixOrigin -ne 'WellKnown'
    } |
    Sort-Object -Property InterfaceMetric, InterfaceIndex

  if (-not $addresses) {
    return '127.0.0.1'
  }
  return $addresses[0].IPAddress
}

function Get-PortProcessIds([int]$Port) {
  return @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique)
}

function Get-ProcessCommandLine([int]$ProcessId) {
  $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
  if (-not $process) {
    return ''
  }
  return [string]$process.CommandLine
}

function Test-BussrutaProcess([int]$ProcessId, [string[]]$Needles) {
  $commandLine = Get-ProcessCommandLine -ProcessId $ProcessId
  if ([string]::IsNullOrWhiteSpace($commandLine)) {
    return $false
  }
  foreach ($needle in $Needles) {
    if ($commandLine.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      return $false
    }
  }
  return $true
}

function Test-BussrutaPortListener([int]$Port, [string]$ServiceName, [string[]]$Needles) {
  $processIds = Get-PortProcessIds -Port $Port
  if (-not $processIds) {
    return $false
  }
  foreach ($processId in $processIds) {
    if ($processId -and (Test-BussrutaProcess -ProcessId $processId -Needles $Needles)) {
      Write-Host "$ServiceName port $Port is already listening for Bussruta (PID $processId)."
      return $true
    }
  }
  $owners = ($processIds | Where-Object { $_ } | ForEach-Object {
    "$_ [$((Get-ProcessCommandLine -ProcessId $_).Trim())]"
  }) -join '; '
  throw "Port $Port is already in use by a non-Bussruta process. Stop it or choose another $ServiceName port. Owner PIDs: $owners"
}

function Stop-BussrutaPortProcess([int]$Port, [string]$ServiceName, [string[]]$Needles) {
  $processIds = Get-PortProcessIds -Port $Port
  foreach ($processId in $processIds) {
    if (-not $processId -or $processId -eq $PID) {
      continue
    }
    if (Test-BussrutaProcess -ProcessId $processId -Needles $Needles) {
      Write-Host "Stopping Bussruta $ServiceName process $processId on port $Port"
      Stop-Process -Id $processId -Force
    } else {
      Write-Host "Leaving non-Bussruta process $processId on port $Port untouched."
    }
  }
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-FirewallRule([string]$Name, [int]$Port) {
  $existing = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Host "Firewall rule already exists: $Name"
    return
  }
  New-NetFirewallRule `
    -DisplayName $Name `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort $Port `
    -Profile Private | Out-Null
  Write-Host "Created firewall rule: $Name"
}

function Start-LoggedProcess([string]$Name, [string]$Command, [string]$LogPath) {
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
  $process = Start-Process `
    -FilePath 'powershell' `
    -ArgumentList @('-NoProfile', '-EncodedCommand', $encodedCommand) `
    -WindowStyle Hidden `
    -PassThru
  Write-Host "$Name started with wrapper PID $($process.Id). Log: $LogPath"
}

function Get-PythonExecutable {
  foreach ($candidate in @('python', 'py', 'python3')) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }
  throw 'Python is required to serve build\web. Install Python or serve build\web with another static web server.'
}

function Invoke-LoggedCommand([string]$Name, [string]$Command, [string]$LogPath) {
  Write-Host "$Name..."
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
  $process = Start-Process `
    -FilePath 'powershell' `
    -ArgumentList @('-NoProfile', '-EncodedCommand', $encodedCommand) `
    -WindowStyle Hidden `
    -Wait `
    -PassThru
  if ($process.ExitCode -ne 0) {
    throw "$Name failed. See log: $LogPath"
  }
}

if ($Help) {
  Show-Help
  exit 0
}

$BuildWeb = Join-Path $RepoRoot 'build\web'
$RelayNeedles = @('tool/internet_relay.dart', "--port $RelayPort")
$WebNeedles = @('http.server', "$WebPort", $BuildWeb)

if ($Stop) {
  Stop-BussrutaPortProcess -Port $RelayPort -ServiceName 'relay' -Needles $RelayNeedles
  Stop-BussrutaPortProcess -Port $WebPort -ServiceName 'web' -Needles $WebNeedles
  Write-Host 'Stopped Bussruta LAN web listeners when they were running.'
  exit 0
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if ($OpenFirewall) {
  if (-not (Test-IsAdmin)) {
    throw 'Run PowerShell as administrator to use -OpenFirewall.'
  }
  Ensure-FirewallRule -Name "Bussruta relay TCP $RelayPort" -Port $RelayPort
  Ensure-FirewallRule -Name "Bussruta web TCP $WebPort" -Port $WebPort
}

if (-not (Test-BussrutaPortListener -Port $RelayPort -ServiceName 'Relay' -Needles $RelayNeedles)) {
  $relayCommand = "Set-Location -LiteralPath '$RepoRoot'; dart run tool/internet_relay.dart --port $RelayPort *> '$RelayLog'"
  Start-LoggedProcess -Name 'Relay' -Command $relayCommand -LogPath $RelayLog
}

if (-not (Test-BussrutaPortListener -Port $WebPort -ServiceName 'Web' -Needles $WebNeedles)) {
  $buildCommand = @"
`$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath '$RepoRoot'
flutter build web --no-wasm-dry-run *> '$BuildLog'
exit `$LASTEXITCODE
"@
  Invoke-LoggedCommand -Name 'Building Flutter web release' -Command $buildCommand -LogPath $BuildLog

  $python = Get-PythonExecutable
  $webCommand = "& '$python' -m http.server $WebPort --bind 0.0.0.0 --directory '$BuildWeb' *> '$WebLog'"
  Start-LoggedProcess -Name 'Static web' -Command $webCommand -LogPath $WebLog
}

Start-Sleep -Seconds 2
$lanAddress = Get-LanAddress

Write-Host ''
Write-Host 'Bussruta same-network browser play is starting.'
Write-Host "Relay URL: ws://$lanAddress`:$RelayPort/ws"
$encodedRelayUrl = [System.Uri]::EscapeDataString("ws://$lanAddress`:$RelayPort/ws")
Write-Host "App URL:   http://$lanAddress`:$WebPort/?relayUrl=$encodedRelayUrl"
Write-Host ''
Write-Host 'Use Hosted mode, choose Host room on one PC, then share the room key.'
Write-Host "Stop later with: powershell -ExecutionPolicy Bypass -File tool\start_lan_web.ps1 -Stop"
