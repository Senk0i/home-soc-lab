<#
Build a small ISO ("LABTOOLS") that holds the lab's scripts, so they can be
attached to a VM as a CD drive. This avoids typing files into VM consoles and
avoids giving isolated VMs an internet connection.

Contents of the ISO:
  ad\       the Active Directory scripts from scripts\ad
  tools\    anything you place in the git-ignored folder <repo>\tools
            (for example Sysmon and its config, installers downloaded on the host)

Output: <repo>\vms\labtools.iso   (git-ignored)

Optionally attach it to a VM's DVD drive:
  .\make-tools-iso.ps1 -AttachTo DC01
#>
param(
    [string]$AttachTo = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$out  = Join-Path $repo 'vms\labtools.iso'
$vbm  = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

$stage = Join-Path $env:TEMP ("labtools-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage\ad", "$stage\tools" | Out-Null
Copy-Item (Join-Path $repo 'scripts\ad\*') "$stage\ad" -Recurse

# Detection content (Wazuh rules and decoders) for the SIEM server.
$detSrc = Join-Path $repo 'detections\wazuh'
if (Test-Path $detSrc) {
    New-Item -ItemType Directory -Force "$stage\detections" | Out-Null
    Copy-Item "$detSrc\*" "$stage\detections" -Recurse
}

# Linux DMZ host: its setup scripts plus the container definitions, side by side.
$dmzSrc = Join-Path $repo 'scripts\dmz'
if (Test-Path $dmzSrc) {
    New-Item -ItemType Directory -Force "$stage\dmz" | Out-Null
    Copy-Item "$dmzSrc\*" "$stage\dmz" -Recurse
    $compose = Join-Path $repo 'configs\dmz\docker-compose.yml'
    if (Test-Path $compose) { Copy-Item $compose "$stage\dmz" }
}
$toolsSrc = Join-Path $repo 'tools'
if (Test-Path $toolsSrc) { Copy-Item "$toolsSrc\*" "$stage\tools" -Recurse }

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class IsoWriter {
    public static void Write(string path, object stream, int blockSize, int totalBlocks) {
        IStream src = (IStream)stream;
        byte[] buf = new byte[blockSize];
        IntPtr read = Marshal.AllocHGlobal(sizeof(int));
        try {
            using (FileStream o = File.Create(path)) {
                for (int i = 0; i < totalBlocks; i++) {
                    src.Read(buf, blockSize, read);
                    int n = Marshal.ReadInt32(read);
                    o.Write(buf, 0, n);
                }
            }
        } finally { Marshal.FreeHGlobal(read); }
    }
}
'@

$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 3          # ISO9660 + Joliet
$fsi.VolumeName = 'LABTOOLS'
$fsi.Root.AddTree($stage, $false)
$result = $fsi.CreateResultImage()
if (Test-Path $out) { Remove-Item $out -Force }
[IsoWriter]::Write($out, $result.ImageStream, $result.BlockSize, $result.TotalBlocks)

# The IMAPI objects keep the staged files open; release them before cleaning up.
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($result)
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($fsi)
[GC]::Collect(); [GC]::WaitForPendingFinalizers()
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("Built {0} ({1} KB)" -f $out, [math]::Round((Get-Item $out).Length / 1KB))

if ($AttachTo) {
    & $vbm storageattach $AttachTo --storagectl SATA --port 1 --device 0 --type dvddrive --medium $out --forceunmount
    Write-Host "Attached to $AttachTo's DVD drive."
}
