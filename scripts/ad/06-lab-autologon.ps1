<#
LAB ONLY, DELIBERATELY LESS SECURE.

Makes a lab VM sign itself in at boot and stops it from locking when idle, so
unattended automation and demos are not interrupted by sign-in screens.

HOW IT WORKS
  Windows' built-in AutoAdminLogon feature reads the account name and password
  from the registry key HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon.
  The password is stored there in plain text, readable by local administrators.
  That is acceptable only on a throwaway, isolated lab machine that holds no real
  data. NEVER use this on a real or internet-connected machine.

THE PASSWORD
  You are prompted for it when the script runs (typed, not echoed). It is never
  written into this repo or passed on the command line.

Run inside DC01 in an elevated PowerShell:
  powershell -ExecutionPolicy Bypass -File D:\ad\06-lab-autologon.ps1

To undo it:
  powershell -ExecutionPolicy Bypass -File D:\ad\06-lab-autologon.ps1 -Remove
#>
param(
    [string]$User   = 'Administrator',
    [string]$Domain = $env:USERDOMAIN,
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'

$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

if ($Remove) {
    Set-ItemProperty $winlogon -Name AutoAdminLogon -Value '0'
    Remove-ItemProperty $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue
    Write-Host 'Auto sign-in removed. The idle-lock settings were left as they are.'
    return
}

function ConvertTo-PlainText([securestring]$s) {
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

# The text is hidden while typing, so ask twice to catch typos.
$plain = $null
foreach ($attempt in 1..3) {
    $p1 = ConvertTo-PlainText (Read-Host -AsSecureString "Password for $Domain\$User (typed here, never stored in the repo)")
    $p2 = ConvertTo-PlainText (Read-Host -AsSecureString 'Type it again to confirm')
    if ($p1 -and $p1 -ceq $p2) { $plain = $p1; break }
    Write-Warning 'The two entries did not match (or were empty). Try again.'
}
if (-not $plain) { throw 'No matching password entered. Nothing was changed.' }
$p1 = $null; $p2 = $null

# Auto sign-in
Set-ItemProperty $winlogon -Name AutoAdminLogon    -Value '1'
Set-ItemProperty $winlogon -Name DefaultUserName   -Value $User
Set-ItemProperty $winlogon -Name DefaultDomainName -Value $Domain
Set-ItemProperty $winlogon -Name DefaultPassword   -Value $plain
$plain = $null

# Do not lock the session when idle
$pol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
Remove-ItemProperty $pol -Name InactivityTimeoutSecs -ErrorAction SilentlyContinue
$ss = 'HKCU:\Control Panel\Desktop'
Set-ItemProperty $ss -Name ScreenSaveActive   -Value '0'
Set-ItemProperty $ss -Name ScreenSaverIsSecure -Value '0'

# Never turn the screen off or sleep, and do not ask for the password on wake
powercfg /change monitor-timeout-ac 0 | Out-Null
powercfg /change standby-timeout-ac 0 | Out-Null
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
powercfg /setactive SCHEME_CURRENT | Out-Null

Write-Host "Auto sign-in enabled for $Domain\$User and idle locking disabled."
Write-Host 'Restart the VM to confirm it signs itself in.'
