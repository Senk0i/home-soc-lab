<#
Phase 4: create the DMZ Docker host that will run the intentionally vulnerable
web app (DVWA) and the SSH honeypot (Cowrie).

  Docker-DMZ   Ubuntu Server 24.04 LTS   1 vCPU (installer)  4 GB  30 GB
  nic1  internal network lab-dmz   (permanent; address 192.168.14.10/24)
  nic2  NAT                        (TEMPORARY, for installing Docker and pulling
                                    images. Remove it with remove-temp-nat.ps1)

Lessons applied: 1 vCPU while installing (2 vCPUs froze every installer on this
host), USB tablet pointer, no clipboard or drag and drop sharing.

Usage:
  .\phase4-create-docker-vm.ps1 -IsoPath ".\isos\ubuntu-24.04.4-live-server-amd64.iso"
#>
param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [string]$Name = 'Docker-DMZ',
    [string]$BaseFolder = (Join-Path (Split-Path $PSScriptRoot -Parent) 'vms')
)

$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $vbm)) { throw 'VBoxManage not found. Install VirtualBox first.' }
$IsoPath = (Resolve-Path $IsoPath).Path
New-Item -ItemType Directory -Force $BaseFolder | Out-Null
if (& $vbm list vms | Select-String -SimpleMatch "`"$Name`"") { Write-Host "$Name already exists."; return }

& $vbm createvm --name $Name --ostype Ubuntu24_LTS_64 --basefolder $BaseFolder --register | Out-Null
& $vbm modifyvm $Name --memory 4096 --cpus 1 --boot1 dvd --boot2 disk --boot3 none --boot4 none `
    --graphicscontroller vmsvga --vram 16 --audio-enabled off `
    --usb-xhci on --mouse usbtablet `
    --clipboard-mode disabled --draganddrop disabled `
    --nic1 intnet --intnet1 lab-dmz --nictype1 82540EM --cableconnected1 on `
    --nic2 nat --nictype2 82540EM --cableconnected2 on

$disk = Join-Path $BaseFolder "$Name\$Name.vdi"
& $vbm createmedium disk --filename $disk --size 30720 --variant Standard | Out-Null
& $vbm storagectl $Name --name SATA --add sata --controller IntelAhci
& $vbm storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
& $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $IsoPath
& $vbm snapshot $Name take '00-created-blank' | Out-Null

Write-Host "$Name created. nic2 is a TEMPORARY NAT adapter: remove it after setup."
