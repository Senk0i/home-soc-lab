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
$src = "$($vol.DriveLetter):\tools\sysmon"

$exe = if ([Environment]::Is64BitOperatingSystem) { 'Sysmon64.exe' } else { 'Sysmon.exe' }
$svc = $exe -replace '\.exe$', ''

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
