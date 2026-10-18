<#
Install Sysmon with the SwiftOnSecurity configuration.

WHAT: Sysmon (System Monitor) is a free Microsoft Sysinternals service that
      records detailed endpoint activity that normal Windows logs leave out:
      every process that starts (with its parent and command line), network
      connections, file creation, registry changes, driver loads and more.
WHY:  Most attack techniques show up as unusual processes and connections.
      Sysmon is the source of those facts, and Wazuh reads its events.

Run inside DC01 and WIN11-CLIENT, in an elevated PowerShell, with the LABTOOLS
CD attached (built by scripts/make-tools-iso.ps1):
  powershell -ExecutionPolicy Bypass -File D:\ad\04-install-sysmon.ps1

NOTE: -accepteula accepts the Sysinternals licence terms (tools\sysmon\Eula.txt).
#>
$ErrorActionPreference = 'Stop'

$vol = Get-Volume | Where-Object FileSystemLabel -eq 'LABTOOLS' | Select-Object -First 1
if (-not $vol) { throw 'LABTOOLS CD not found. Attach labtools.iso to this VM first.' }

# Run from a local copy: the installer copies itself into C:\Windows and works
# more reliably from a normal folder than from a CD.
$src = 'C:\lab\sysmon'
New-Item -ItemType Directory -Force $src | Out-Null
Copy-Item "$($vol.DriveLetter):\tools\sysmon\*" $src -Force

$exe = if ([Environment]::Is64BitOperatingSystem) { 'Sysmon64.exe' } else { 'Sysmon.exe' }
$svc = $exe -replace '\.exe$', ''

# A failed earlier attempt can leave a read-only copy in C:\Windows with no service,
# which makes every retry fail with "Access is denied". Remove such a stale copy.
$stale = Join-Path $env:SystemRoot $exe
if ((Test-Path $stale) -and -not (Get-Service $svc -ErrorAction SilentlyContinue)) {
    Write-Host "Removing stale $stale left by a previous failed install."
    Remove-Item $stale -Force
}

if (Get-Service $svc -ErrorAction SilentlyContinue) {
    Write-Host "$svc already installed; updating configuration."
    & "$src\$exe" -accepteula -c "$src\sysmonconfig-export.xml"
} else {
    Write-Host "Installing $svc ..."
    & "$src\$exe" -accepteula -i "$src\sysmonconfig-export.xml"
}

Start-Sleep -Seconds 3
Get-Service $svc | Format-Table Name, Status, StartType -AutoSize
Write-Host 'Most recent Sysmon events (event ID 1 = process created, 3 = network connection):'
Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 5 |
    Format-Table TimeCreated, Id, @{n='Message'; e={ ($_.Message -split "`n")[0] }} -AutoSize
