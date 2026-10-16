# Phase 10: Lab v2 on Proxmox

Status: **planned**. This phase starts after the VirtualBox baseline (Phases 0 to 9) is working and documented.

## Goal

Rebuild the same lab on a dedicated Proxmox VE host, with the build driven from code, so the whole environment can be created, reset and torn down on demand. The network design, IP plan and detection work stay the same. What changes is the platform and how it is built.

## Why

| Today (VirtualBox on a Windows laptop) | Lab v2 (Proxmox on a dedicated machine) |
|---|---|
| Hypervisor sits on top of Windows' own hypervisor, so installers froze with 2 vCPUs | Native KVM virtualization, no nested layers |
| VMs created with PowerShell and `VBoxManage` | VMs created from templates with Terraform and Ansible |
| Console windows on the laptop | Browser-based console, no mouse or keyboard capture problems |
| The laptop runs everything and is busy | The laptop is only the workstation |
| Snapshots | Snapshots, clone templates and scheduled backups |

## Scope

In scope: the same zones and machines, rebuilt on Proxmox.

| Zone | Subnet | Machines |
|---|---|---|
| Attacker | 192.168.1.0/24 | Kali |
| DMZ | 192.168.14.0/24 | Docker host: DVWA + honeypot |
| Transit | 192.168.20.0/24 | between the two firewalls |
| SOC | 192.168.11.0/24 | Wazuh, Splunk, Shuffle |
| AD | 192.168.30.0/24 | Domain controller + Windows client |

Out of scope: exposing any lab system to the internet, and any change to the detection content itself.

## Platform

- **Host:** a spare desktop-class machine dedicated to Proxmox VE. Target spec: 32 GB RAM, an SSD of at least 500 GB, CPU virtualization (VT-x or AMD-V) enabled, one network port.
- **Management:** Proxmox's web page on the home network for administration only. Strong unique password, no port forwarding, no internet exposure.
- **Lab networks:** Linux bridges with no physical port (`vmbr1` to `vmbr5`), one per zone, or one VLAN-aware bridge. They never connect to the home network, which keeps the same isolation guarantee as the VirtualBox internal networks.

## Resource plan for 32 GB

Profiles, not everything at once, as in the baseline.

| Profile | Runs | Approx. RAM |
|---|---|---|
| Core | pfSense-A, pfSense-B, domain controller, Windows client, Wazuh | ~22 GB |
| Attack | Core + Kali + DMZ Docker host | ~30 GB |
| SIEM (swap in) | Splunk instead of the attack machines | ~30 GB |

Splunk, Elastic and Shuffle together do not fit in 32 GB, so they are started in turn.

## Build design

1. **Templates.** One cloud-init Linux template (Ubuntu) for Wazuh, Splunk, Shuffle and the Docker host. One sysprepped Windows Server 2025 template and one Windows 11 template (UEFI, virtual TPM, VirtIO drivers).
2. **Networks.** Defined in code: bridges, VLANs and VM NIC assignments.
3. **Terraform.** Creates every VM from a template and attaches it to the right bridges. State stays local and is never committed.
4. **Ansible.** Configures what Terraform builds: Wazuh server and agents, Sysmon, Splunk, the Docker host, and the Active Directory domain.
5. **Firewalls.** The existing pfSense baseline scripts (`configs/pfsense/`) are reused. pfSense configuration can also be imported as a saved config.
6. **Active Directory.** The existing scripts (`scripts/ad/`) are reused, or ported to Ansible.

## What carries over unchanged

- The IP plan and zone design (`docs/architecture.md`)
- The firewall rules (`configs/pfsense/*.php`)
- The Active Directory structure and test users (`scripts/ad/*.ps1`)
- Detections, attack scenarios and incident reports (these are platform independent)

## What changes

- VM creation and networking (Terraform and Proxmox bridges instead of `VBoxManage` and internal networks)
- Windows templates need VirtIO drivers
- The CPU and mouse workarounds from the VirtualBox lessons no longer apply

## Secrets

- Proxmox API tokens, passwords and Terraform state are git-ignored and never committed.
- Lab passwords follow the same rule as the baseline: typed at prompts, kept outside the repo.

## Milestones

- [ ] Proxmox installed on the dedicated host, updated, management secured
- [ ] Lab bridges created, with no path to the home network (verified)
- [ ] pfSense-A and pfSense-B rebuilt, baseline rules applied, isolation tests pass
- [ ] Ubuntu and Windows templates built
- [ ] Terraform builds the full Core profile from scratch
- [ ] Ansible configures Wazuh and the agents
- [ ] Active Directory domain rebuilt from the scripts and joined
- [ ] One-command rebuild of the whole lab documented
- [ ] Comparison write-up: VirtualBox baseline versus Proxmox v2

## Risks

- The target machine is wiped when Proxmox is installed. Back up anything on it first.
- 32 GB limits how many heavy tools run at once.
- Windows evaluation licences expire, so the rebuild-from-code design is also how they are refreshed.
