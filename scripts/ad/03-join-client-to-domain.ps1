<#
Run inside WIN11-CLIENT in an elevated PowerShell, after Windows 11 is
installed and the DC is up.

Sets the static address with the DC as DNS, checks the domain is reachable,
renames the machine, and joins it to the domain. You are prompted for domain
administrator credentials by Add-Computer. The machine reboots afterwards.
#>
$ErrorActionPreference = 'Stop'

$ip      = '192.168.30.20'
$gateway = '192.168.30.1'
$dns     = '192.168.30.10'
$domain  = 'soclab.local'

$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $ip -PrefixLength 24 -DefaultGateway $gateway | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $dns

# The adapter needs a few seconds after the address change; retry before giving up.
$reachable = $false
foreach ($i in 1..15) {
    try { if (Test-Connection $dns -Count 1 -Quiet -ErrorAction Stop) { $reachable = $true; break } } catch { }
    Start-Sleep -Seconds 4
}
if (-not $reachable) { throw "Cannot reach the domain controller at $dns" }
Resolve-DnsName $domain -ErrorAction Stop | Out-Null

Add-Computer -DomainName $domain -NewName 'WIN11-CLIENT' `
    -OUPath 'OU=Workstations,OU=SOCLab,DC=soclab,DC=local' -Restart
