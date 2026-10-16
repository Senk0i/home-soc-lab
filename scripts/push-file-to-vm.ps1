<#
Copy a small text file into a VM whose console is sitting at a shell prompt
(for example pfSense menu option 8), without any network connection.

The file is base64-encoded, typed into the console in small chunks with
VBoxManage, then decoded inside the VM. Intended for small config scripts.

Usage:
  .\push-file-to-vm.ps1 -Vm pfSense-A -File ..\configs\pfsense\pfsense-a-baseline.php -Dest /root/baseline.php
#>
param(
    [Parameter(Mandatory = $true)][string]$Vm,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][string]$Dest,
    [int]$ChunkSize = 160
)

$ErrorActionPreference = 'Stop'
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

function Send-Line([string]$text) {
    & $vbm controlvm $Vm keyboardputstring $text
    Start-Sleep -Milliseconds 300
    & $vbm controlvm $Vm keyboardputscancode 1c 9c
    Start-Sleep -Milliseconds 600
}

$bytes = [IO.File]::ReadAllBytes((Resolve-Path $File))
$b64 = [Convert]::ToBase64String($bytes)
$tmp = "/tmp/push.b64"

Send-Line "rm -f $tmp"
for ($i = 0; $i -lt $b64.Length; $i += $ChunkSize) {
    $chunk = $b64.Substring($i, [Math]::Min($ChunkSize, $b64.Length - $i))
    Send-Line "echo -n $chunk >> $tmp"
}
Send-Line "b64decode -r $tmp > $Dest"
Send-Line "wc -c $Dest"
Write-Host "Sent $($bytes.Length) bytes to ${Vm}:$Dest"
