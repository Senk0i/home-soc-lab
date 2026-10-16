# Phase 2: Active Directory

Goal: a small Windows domain (`soclab.local`) on the isolated AD network, so there are realistic accounts, logons and Windows events to attack and detect in later phases.

## Design

| Host | Role | Address | vCPU / RAM / disk |
|---|---|---|---|
| DC01 | Windows Server 2022: domain controller + DNS | 192.168.30.10/24 | 2 / 4 GB / 60 GB |
| WIN11-CLIENT | Windows 11 domain-joined workstation | 192.168.30.20/24 | 2 / 4 GB / 64 GB |

Both attach only to the internal network `lab-ad`. The gateway is pfSense-B (192.168.30.1). The client uses the DC (192.168.30.10) as its DNS server.

Domain: `soclab.local`, NetBIOS name `SOCLAB`.

## Prerequisites

Download two ISOs and save them in this project's git-ignored `isos/` folder:

1. **Windows Server 2022 Evaluation** (ISO, 64-bit, English) from the Microsoft Evaluation Center. Choose the Desktop Experience edition when installing.
2. **Windows 11 ISO** (multi-edition, x64, English) from Microsoft's Windows 11 download page. Choose **Windows 11 Pro** at setup: it can join a domain, and it runs unactivated for lab use.

No product keys are needed. The Server evaluation runs for 180 days.

## Steps

1. **Create the VMs:** `scripts/phase2-create-ad-vms.ps1 -ServerIso <iso> -ClientIso <iso>`. It builds both VMs on `lab-ad` and snapshots them blank. Windows 11 gets UEFI, Secure Boot and a virtual TPM 2.0.
2. **Install Windows Server on DC01.** Choose "Windows Server 2022 Standard Evaluation (Desktop Experience)", custom install, the 60 GB disk. Set the Administrator password during setup. Use a lab-only password and keep it out of this repo.
3. **Promote the domain controller:** in an elevated PowerShell on DC01, run `scripts/ad/01-promote-domain-controller.ps1`. It sets 192.168.30.10, installs AD DS and DNS, and creates the forest. It asks for a DSRM password and reboots.
4. **Create OUs and users:** after the reboot, sign in as `SOCLAB\Administrator` and run `scripts/ad/02-create-ous-and-users.ps1`. It asks once for a lab password for the test users.
5. **Install Windows 11 on WIN11-CLIENT.** Pick Windows 11 Pro. Use a local account (the lab has no internet, so skip the Microsoft account step).
6. **Join the domain:** in an elevated PowerShell on the client, run `scripts/ad/03-join-client-to-domain.ps1`. It asks for domain administrator credentials.
7. **Install Sysmon on both machines** (see below), then snapshot both as `01-phase2-domain`.

## Sysmon

Sysmon logs process creation, network connections, registry and file changes. Wazuh will collect these events in Phase 3.

The lab has no internet access. To fetch Sysmon and a config, temporarily give each VM a second adapter set to NAT, download, then remove it again:

```
VBoxManage modifyvm <vm> --nic2 nat        # VM powered off
VBoxManage modifyvm <vm> --nic2 none       # remove it afterwards
```

Use the SwiftOnSecurity `sysmonconfig-export.xml` as the starting configuration.

## Verification

- `nltest /dsgetdc:soclab.local` on the client returns DC01.
- A domain user (for example `alex.rivera`) can sign in on WIN11-CLIENT.
- From the client, `ping 192.168.30.1` works, and `ping 192.168.14.1` works (AD may reach the DMZ).
- From the client, the attacker and transit networks are unreachable (inner firewall default deny).
- Event Viewer on DC01 shows logon events 4624 and 4625 when signing in and when entering a wrong password.

## Notes

- Test users share one throwaway lab password, entered at a prompt, never stored in files. The accounts are deliberately ordinary so attack scenarios have realistic targets.
- Keep the VMs at 2 vCPU. If a VM freezes during install under the Windows hypervisor, drop it to 1 vCPU for the install, then raise it.
