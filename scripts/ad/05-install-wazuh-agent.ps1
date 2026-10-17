<#
Install the Wazuh agent and point it at the Wazuh server.

WHAT: The Wazuh agent is a small background service. It reads Windows event
      logs (including the Sysmon channel), watches files and settings, and sends
      what it finds to the Wazuh server over the network.
WHY:  A SIEM is only as good as the data it receives. The agent is how each
      endpoint's activity reaches the central place where rules and dashboards
      work on it. It connects on TCP 1514 (events) and 1515 (first-time
      enrolment), the ports the lab firewalls allow.

Run inside DC01 and WIN11-CLIENT, in an elevated PowerShell, with the LABTOOLS
CD attached, AFTER the Wazuh server is running at 192.168.11.10:
  powershell -ExecutionPolicy Bypass -File D:\ad\05-install-wazuh-agent.ps1
#>
param(
    [string]$ManagerIp = '192.168.11.10',
    [string]$Version = '4.14.9-1'
)
$ErrorActionPreference = 'Stop'

$vol = Get-Volume | Where-Object FileSystemLabel -eq 'LABTOOLS' | Select-Object -First 1
if (-not $vol) { throw 'LABTOOLS CD not found. Attach labtools.iso to this VM first.' }
$msi = "$($vol.DriveLetter):\tools\wazuh\wazuh-agent-$Version.msi"
if (-not (Test-Path $msi)) { throw "Installer not found: $msi" }

if (-not (Test-NetConnection $ManagerIp -Port 1515 -InformationLevel Quiet -WarningAction SilentlyContinue)) {
    Write-Warning "Cannot reach $ManagerIp on port 1515 yet. Installing anyway; the agent keeps retrying."
}

$svcName = 'WazuhSvc'
if (-not (Get-Service $svcName -ErrorAction SilentlyContinue)) {
    $args = "/i `"$msi`" /q WAZUH_MANAGER=`"$ManagerIp`" WAZUH_AGENT_NAME=`"$env:COMPUTERNAME`""
    Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow
}

# Tell the agent to also read the Sysmon event channel.
$conf = 'C:\Program Files (x86)\ossec-agent\ossec.conf'
$text = Get-Content $conf -Raw
if ($text -notmatch 'Microsoft-Windows-Sysmon/Operational') {
    $block = @"

  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>

</ossec_config>
"@
    $idx = $text.LastIndexOf('</ossec_config>')
    $text = $text.Substring(0, $idx) + $block
    Set-Content -Path $conf -Value $text -Encoding UTF8
    Write-Host 'Added the Sysmon event channel to the agent configuration.'
}

Restart-Service $svcName
Start-Sleep -Seconds 5
Get-Service $svcName | Format-Table Name, Status, StartType -AutoSize
Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 8
