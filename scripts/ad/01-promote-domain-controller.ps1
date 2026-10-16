<#
Run inside DC01 in an elevated PowerShell, after Windows Server is installed.

Sets the static address, renames the server, installs AD DS and DNS, and
promotes it to the first domain controller of a new forest. The server
reboots when promotion finishes.

You are prompted for the Directory Services Restore Mode (DSRM) password.
Nothing secret is stored in this file.
#>
$ErrorActionPreference = 'Stop'

$ip      = '192.168.30.10'
$prefix  = 24
$gateway = '192.168.30.1'
$domain  = 'soclab.local'
$netbios = 'SOCLAB'

# Static address. DNS points at itself because this server will run DNS.
$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gateway | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses '127.0.0.1'

if ($env:COMPUTERNAME -ne 'DC01') { Rename-Computer -NewName 'DC01' -Force }

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

# Prompts for the DSRM password.
Install-ADDSForest `
    -DomainName $domain `
    -DomainNetbiosName $netbios `
    -InstallDns `
    -DatabasePath 'C:\Windows\NTDS' `
    -LogPath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -NoRebootOnCompletion:$false `
    -Force
