<#
Phase 1: create the two pfSense VMs and the isolated networks they use.

VirtualBox "internal networks" are named virtual switches that exist only
inside VirtualBox. They are never connected to the host or the home LAN.

  pfSense-A (edge):  nic1 lab-attacker (WAN)  nic2 lab-dmz  nic3 lab-transit
  pfSense-B (inner): nic1 lab-transit  (WAN)  nic2 lab-soc  nic3 lab-ad

Usage:
  .\phase1-create-pfsense.ps1 -IsoPath "C:\path\to\netgate-installer.iso"
#>
param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [string]$BaseFolder = "$env:USERPROFILE\VirtualBox VMs"
)

$ErrorActionPreference = 'Stop'
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $vbm)) { throw "VBoxManage not found. Install VirtualBox first." }
if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }

function New-PfSenseVM {
    param([string]$Name, [string[]]$Networks)

    $existing = & $vbm list vms | Select-String -SimpleMatch "`"$Name`""
    if ($existing) { Write-Host "$Name already exists, skipping."; return }

    Write-Host "Creating $Name ..."
    & $vbm createvm --name $Name --ostype FreeBSD_64 --basefolder $BaseFolder --register | Out-Null
    & $vbm modifyvm $Name --memory 1024 --cpus 1 --boot1 dvd --boot2 disk --boot3 none --boot4 none `
        --graphicscontroller vmsvga --vram 16 --audio-enabled off --usb-ohci off

    for ($i = 0; $i -lt $Networks.Count; $i++) {
        $n = $i + 1
        & $vbm modifyvm $Name "--nic$n" intnet "--intnet$n" $Networks[$i] "--nictype$n" 82540EM "--cableconnected$n" on
    }

    # Temporary NAT adapter: the Netgate Installer downloads pfSense over the internet.
    # Disable it (VM Settings > Network > uncheck "Enable Network Adapter") after install.
    $natNic = $Networks.Count + 1
    & $vbm modifyvm $Name "--nic$natNic" nat "--nictype$natNic" 82540EM "--cableconnected$natNic" on

    $disk = Join-Path $BaseFolder "$Name\$Name.vdi"
    & $vbm createmedium disk --filename $disk --size 16384 --variant Standard | Out-Null
    & $vbm storagectl $Name --name SATA --add sata --controller IntelAhci
    & $vbm storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
    & $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $IsoPath

    & $vbm snapshot $Name take "00-created-blank" | Out-Null
    Write-Host "$Name ready."
}

New-PfSenseVM -Name "pfSense-A" -Networks @("lab-attacker", "lab-dmz", "lab-transit")
New-PfSenseVM -Name "pfSense-B" -Networks @("lab-transit", "lab-soc", "lab-ad")

Write-Host ""
Write-Host "Done. Start a VM with:  VBoxManage startvm pfSense-A --type gui"
