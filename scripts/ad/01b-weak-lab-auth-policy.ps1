<#
OPTIONAL and DELIBERATELY INSECURE. Run inside DC01 in an elevated PowerShell
after the domain exists, before creating the test users.

Relaxes the domain password policy so lab users can have simple passwords, and
turns off account lockout so brute-force and password-spraying practice is not
cut short. This is for training inside the isolated lab network only. Never use
these settings on a real environment.

To restore a normal policy later:
  Set-ADDefaultDomainPasswordPolicy -Identity soclab.local -ComplexityEnabled $true `
      -MinPasswordLength 12 -LockoutThreshold 5
#>
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domain = (Get-ADDomain).DNSRoot

Set-ADDefaultDomainPasswordPolicy -Identity $domain `
    -ComplexityEnabled $false `
    -MinPasswordLength 1 `
    -MinPasswordAge 0.00:00:00 `
    -PasswordHistoryCount 0 `
    -LockoutThreshold 0

Get-ADDefaultDomainPasswordPolicy | Format-List ComplexityEnabled, MinPasswordLength, PasswordHistoryCount, LockoutThreshold
