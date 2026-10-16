<#
Phase 1: create the Kali VM used first as the admin workstation for the
pfSense web UI, later as the attacker.

Kali starts on lab-dmz so it can reach pfSense-A at https://192.168.14.1.
Move it to another lab network with:
  VBoxManage modifyvm Kali --intnet1 lab-soc
(power the VM off first).

Usage:
  .\phase1-create-kali.ps1 -IsoPath ".\isos\kali-linux-<version>-installer-amd64.iso"
#>
param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [string]$Network = "lab-dmz",
    [string]$BaseFolder = (Join-Path (Split-Path $PSScriptRoot -Parent) "vms")
)

$ErrorActionPreference = 'Stop'
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$Name = "Kali"

if (-not (Test-Path $vbm)) { throw "VBoxManage not found. Install VirtualBox first." }
if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }
$IsoPath = (Resolve-Path $IsoPath).Path
New-Item -ItemType Directory -Force $BaseFolder | Out-Null

if (& $vbm list vms | Select-String -SimpleMatch "`"$Name`"") { Write-Host "$Name already exists."; return }

Write-Host "Creating $Name on $Network ..."
& $vbm createvm --name $Name --ostype Debian_64 --basefolder $BaseFolder --register | Out-Null
& $vbm modifyvm $Name --memory 4096 --cpus 2 --boot1 dvd --boot2 disk --boot3 none --boot4 none `
    --graphicscontroller vmsvga --vram 128 --audio-enabled off `
    --nic1 intnet --intnet1 $Network --nictype1 82540EM --cableconnected1 on `
    --clipboard-mode disabled --draganddrop disabled

$disk = Join-Path $BaseFolder "$Name\$Name.vdi"
& $vbm createmedium disk --filename $disk --size 40960 --variant Standard | Out-Null
& $vbm storagectl $Name --name SATA --add sata --controller IntelAhci
& $vbm storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
& $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $IsoPath
& $vbm snapshot $Name take "00-created-blank" | Out-Null

Write-Host "$Name ready. Start it with:  VBoxManage startvm $Name --type gui"
