# Phase 0: Host check

Goal: confirm the laptop can host the lab and decide on the hypervisor before building anything.

## Findings

| Check | Result | Verdict |
|---|---|---|
| CPU | AMD Ryzen AI 7 350, 8 cores / 16 threads (Framework Laptop 13) | Good |
| CPU virtualization (SVM) in firmware | Enabled | Good |
| RAM | 64 GB | Good |
| Free disk on C: | ~228 GB | Tight, use thin disks and delete old snapshots |
| Windows hypervisor | Running (virtualization-based security is on) | See hypervisor decision |
| git | Installed | Good |
| git identity (`user.name`, `user.email`) | Not set | Set before first commit |
| GitHub CLI (`gh`) | Not installed | Install before publishing |
| Docker | Not installed on host (not needed, runs inside the DMZ VM) | Fine |
| VMware Workstation | Not installed | Install if chosen |

## Why disk space matters

The lab is roughly 10 VMs. Thin-provisioned, expect 120 to 170 GB of real usage once everything is built. With ~228 GB free there is room, but not for many snapshots. If the disk fills up, VMs pause.

## Hypervisor decision

The Windows hypervisor is already active on this machine, which VMware Workstation and VirtualBox have to share.

| Option | Pros | Cons |
|---|---|---|
| VMware Workstation (free personal use) | Easy custom virtual networks, `vmrun` scripting, good snapshots | Runs on top of the Windows hypervisor, so somewhat slower |
| Hyper-V (built into Windows 11 Pro) | Native speed, no extra install | Networking is clunkier, no free nested-network UI, scripting is PowerShell only |

Decision: **VirtualBox 7.2.20**, installed via winget. VMware Workstation requires a Broadcom account to download, and VirtualBox gives named internal networks (never touching the host LAN) plus a fully scriptable `VBoxManage` CLI.

## Hypervisor-specific network mapping

See [phase-1-networks-and-firewalls.md](phase-1-networks-and-firewalls.md).

## Fixes before Phase 1

1. Set git identity: `git config --global user.name "<name>"` and `git config --global user.email "<email>"`.
2. Install GitHub CLI and run `gh auth login` (only needed before publishing).
3. Install the chosen hypervisor.
4. Download ISOs: pfSense CE, Windows Server 2022 evaluation, Windows 11 evaluation, Kali, Ubuntu Server 22.04 (for Wazuh, Splunk, Docker hosts).
