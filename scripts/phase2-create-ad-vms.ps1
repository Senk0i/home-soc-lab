<#
Phase 2: create the Active Directory VMs on the isolated lab-ad network.

  DC01          Windows Server 2025   2 vCPU  4 GB  60 GB   192.168.30.10
  WIN11-CLIENT  Windows 11            2 vCPU  4 GB  64 GB   192.168.30.20

Both VMs attach to the internal network "lab-ad" only. Addresses are set
inside Windows after install (see docs/build-guide/phase-2-active-directory.md).

Usage:
  .\phase2-create-ad-vms.ps1 -ServerIso ".\isos\<server-2025-eval>.iso" -ClientIso ".\isos\<windows-11>.iso"
#>
param(
    [Parameter(Mandatory = $true)][string]$ServerIso,
    [Parameter(Mandatory = $true)][string]$ClientIso,
    [string]$Network = "lab-ad",
    [string]$BaseFolder = (Join-Path (Split-Path $PSScriptRoot -Parent) "vms")
)

$ErrorActionPreference = 'Stop'
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $vbm)) { throw "VBoxManage not found. Install VirtualBox first." }
$ServerIso = (Resolve-Path $ServerIso).Path
$ClientIso = (Resolve-Path $ClientIso).Path
New-Item -ItemType Directory -Force $BaseFolder | Out-Null

function Test-VmExists([string]$Name) {
    [bool](& $vbm list vms | Select-String -SimpleMatch "`"$Name`"")
}

function New-LabVm {
    param([string]$Name, [string]$OsType, [string]$Iso, [int]$DiskMB, [bool]$Windows11)

    if (Test-VmExists $Name) { Write-Host "$Name already exists, skipping."; return }
    Write-Host "Creating $Name ..."

    & $vbm createvm --name $Name --ostype $OsType --basefolder $BaseFolder --register | Out-Null
    & $vbm modifyvm $Name --memory 4096 --cpus 2 --boot1 dvd --boot2 disk --boot3 none --boot4 none `
        --graphicscontroller vboxsvga --vram 128 --audio-enabled off `
        --nic1 intnet --intnet1 $Network --nictype1 82540EM --cableconnected1 on `
        --clipboard-mode disabled --draganddrop disabled `
        --usb-xhci on --mouse usbtablet   # absolute pointer: a PS/2 mouse drifts and gets captured

    if ($Windows11) {
        # Windows 11 needs UEFI, Secure Boot and a TPM 2.0
        & $vbm modifyvm $Name --firmware efi --tpm-type 2.0
        & $vbm modifynvram $Name inituefivarstore | Out-Null
        & $vbm modifynvram $Name enrollmssignatures | Out-Null
        & $vbm modifynvram $Name enrollorclpk | Out-Null
    }

    $disk = Join-Path $BaseFolder "$Name\$Name.vdi"
    & $vbm createmedium disk --filename $disk --size $DiskMB --variant Standard | Out-Null
    & $vbm storagectl $Name --name SATA --add sata --controller IntelAhci
    & $vbm storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
    & $vbm storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso
    & $vbm snapshot $Name take "00-created-blank" | Out-Null
    Write-Host "$Name ready."
}

New-LabVm -Name "DC01" -OsType "Windows2025_64" -Iso $ServerIso -DiskMB 61440 -Windows11 $false
New-LabVm -Name "WIN11-CLIENT" -OsType "Windows11_64" -Iso $ClientIso -DiskMB 65536 -Windows11 $true

Write-Host ""
Write-Host "Done. Start one with:  VBoxManage startvm DC01 --type gui"
