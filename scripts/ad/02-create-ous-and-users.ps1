<#
Run inside DC01 in an elevated PowerShell, after the domain controller has
rebooted and you can sign in as the domain administrator.

Creates an OU structure and a handful of ordinary lab users so there is
realistic activity to attack and detect. You are prompted ONCE for a lab
password that is used for all test users. It is never written to disk or to
this repo. Use a throwaway password that you do not use anywhere else.
#>
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$root = (Get-ADDomain).DistinguishedName
$base = "OU=SOCLab,$root"

if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$base'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name 'SOCLab' -Path $root -ProtectedFromAccidentalDeletion $false
}
foreach ($ou in 'Users', 'Workstations', 'Servers', 'ServiceAccounts', 'Admins') {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $base -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $base -ProtectedFromAccidentalDeletion $false
    }
}

$pw = Read-Host -AsSecureString 'Lab password for all test users'

$users = @(
    @{ Sam = 'alex.rivera';  Name = 'Alex Rivera';  OU = 'Users';           Title = 'Analyst' },
    @{ Sam = 'sam.chen';     Name = 'Sam Chen';     OU = 'Users';           Title = 'Accountant' },
    @{ Sam = 'jordan.lee';   Name = 'Jordan Lee';   OU = 'Users';           Title = 'HR Manager' },
    @{ Sam = 'svc.backup';   Name = 'Backup Service'; OU = 'ServiceAccounts'; Title = 'Service account' },
    @{ Sam = 'adm.helpdesk'; Name = 'Helpdesk Admin'; OU = 'Admins';        Title = 'IT helpdesk' }
)

foreach ($u in $users) {
    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue) { continue }
    New-ADUser -SamAccountName $u.Sam -Name $u.Name -GivenName ($u.Name -split ' ')[0] `
        -Surname ($u.Name -split ' ')[-1] -Title $u.Title `
        -UserPrincipalName "$($u.Sam)@$((Get-ADDomain).DNSRoot)" `
        -Path "OU=$($u.OU),$base" -AccountPassword $pw -Enabled $true -PasswordNeverExpires $true
}

Get-ADUser -Filter * -SearchBase $base | Select-Object SamAccountName, DistinguishedName | Format-Table -AutoSize
