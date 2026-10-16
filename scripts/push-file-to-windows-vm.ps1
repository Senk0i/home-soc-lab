<#
Copy a small text file into a WINDOWS VM whose console has an open PowerShell
prompt, with no network connection needed.

The file is base64-encoded, typed into the console in small chunks with
VBoxManage, then decoded inside the VM. Windows counterpart of
push-file-to-vm.ps1 (which targets a Unix shell).

Usage:
  .\push-file-to-windows-vm.ps1 -Vm DC01 -File .\ad\01-promote-domain-controller.ps1 -Dest C:\lab\01-promote.ps1
#>
param(
    [Parameter(Mandatory = $true)][string]$Vm,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][string]$Dest,
    [int]$ChunkSize = 150
)

$ErrorActionPreference = 'Stop'
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

function Send-Line([string]$text, [int]$pauseMs = 700) {
    & $vbm controlvm $Vm keyboardputstring $text
    Start-Sleep -Milliseconds 300
    & $vbm controlvm $Vm keyboardputscancode 1c 9c
    Start-Sleep -Milliseconds $pauseMs
}

$bytes = [IO.File]::ReadAllBytes((Resolve-Path $File))
$b64 = [Convert]::ToBase64String($bytes)
$dir = Split-Path $Dest -Parent

Send-Line "New-Item -ItemType Directory -Force '$dir' | Out-Null; `$b = ''"
for ($i = 0; $i -lt $b64.Length; $i += $ChunkSize) {
    $chunk = $b64.Substring($i, [Math]::Min($ChunkSize, $b64.Length - $i))
    Send-Line "`$b += '$chunk'"
}
Send-Line "[IO.File]::WriteAllBytes('$Dest', [Convert]::FromBase64String(`$b)); (Get-Item '$Dest').Length" 1500
Write-Host "Sent $($bytes.Length) bytes to ${Vm}:$Dest"
