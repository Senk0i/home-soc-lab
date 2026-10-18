<#
Remove the temporary NAT (internet) adapter from a lab VM and prove it is gone.

Run this on the host with the VM powered off. It disables adapter 2, then lists
every adapter on the VM so you can confirm only internal lab networks remain.

Usage:
  .\remove-temp-nat.ps1 -Vm Docker-DMZ
#>
param([Parameter(Mandatory = $true)][string]$Vm, [int]$Nic = 2)

$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

$state = (& $vbm showvminfo $Vm --machinereadable | Select-String '^VMState="(.*)"').Matches.Groups[1].Value
if ($state -ne 'poweroff') { throw "$Vm must be powered off first (state: $state)." }

& $vbm modifyvm $Vm "--nic$Nic" none

Write-Host "Adapters on ${Vm}:"
$info = & $vbm showvminfo $Vm --machinereadable
$bad = @()
1..8 | ForEach-Object {
    $mode = ($info | Select-String "^nic$($_)=`"(.*)`"").Matches.Groups[1].Value
    if ($mode -and $mode -ne 'none') {
        $net = ($info | Select-String "^intnet$($_)=`"(.*)`"").Matches.Groups[1].Value
        Write-Host ("  nic{0}: {1} {2}" -f $_, $mode, $net)
        if ($mode -ne 'intnet') { $bad += "nic$_ ($mode)" }
    }
}
if ($bad) { throw "NOT isolated: $($bad -join ', ') is not an internal network." }
Write-Host 'Verified: only internal lab networks remain. The VM has no internet access.'
