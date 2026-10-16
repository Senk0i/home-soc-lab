# Phase 1: Virtual networks and pfSense firewalls

Goal: two layered pfSense firewalls and five isolated virtual networks, with default-deny from the DMZ.

## Hypervisor

VirtualBox 7.2. Each zone is a named **internal network**. Internal networks live only inside VirtualBox and never reach the host or the home LAN.

| Zone | Internal network name | Subnet |
|---|---|---|
| Attacker / outside | `lab-attacker` | 192.168.1.0/24 |
| DMZ | `lab-dmz` | 192.168.14.0/24 |
| Transit | `lab-transit` | 192.168.20.0/24 |
| SOC | `lab-soc` | 192.168.11.0/24 |
| AD | `lab-ad` | 192.168.30.0/24 |

## NIC layout

| VM | NIC 1 | NIC 2 | NIC 3 |
|---|---|---|---|
| pfSense-A (edge) | `lab-attacker` (WAN, 192.168.1.1) | `lab-dmz` (LAN, 192.168.14.1) | `lab-transit` (OPT1, 192.168.20.1) |
| pfSense-B (inner) | `lab-transit` (WAN, 192.168.20.2) | `lab-soc` (LAN, 192.168.11.1) | `lab-ad` (OPT1, 192.168.30.1) |

## Steps

1. **Get the pfSense ISO.** pfSense CE 2.7.2 (full offline installer) is on Netgate's mirror: `https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz`. Verify it against the `.sha256` file next to it, then extract the `.gz`. Keep the ISO in Downloads, not in this repo. The newer 2.8.x line is only distributed through the Netgate Installer store checkout, which downloads packages during install and needs internet.
2. **Create both VMs** with `scripts/phase1-create-pfsense.ps1 -IsoPath <iso>`. It creates the VMs inside this repo's git-ignored `vms/` folder, with the NIC-to-network mapping, a 16 GB thin disk each, and a blank snapshot. The lab networks are isolated, with no internet adapter.
3. **Install pfSense-A.** Start it, accept the license, choose the guided install (ZFS or UFS) on the 16 GB disk, then reboot and remove the ISO.
4. **Assign interfaces** from the console menu (option 1): `em0` = WAN, `em1` = LAN, `em2` = OPT1. Set addresses with option 2:
   - WAN: static `192.168.1.1/24`, no gateway
   - LAN: static `192.168.14.1/24`, DHCP off
   - OPT1: static `192.168.20.1/24`, DHCP off
5. **Repeat for pfSense-B** with its own addresses (see NIC layout). WAN `192.168.20.2/24` with upstream gateway `192.168.20.1`.
6. **Reach the web UI.** The pfSense GUI is only reachable from a LAN-side machine. For pfSense-A, temporarily attach Kali's NIC to `lab-dmz` and browse to `https://192.168.14.1`. For pfSense-B, use the Windows client once it exists in the AD zone (Phase 2), or a temporary Linux VM on `lab-soc`.
7. **Routing.** Add static routes so each firewall knows the networks behind the other:
   - pfSense-A: `192.168.11.0/24` and `192.168.30.0/24` via `192.168.20.2`
   - pfSense-B: default gateway `192.168.20.1`
8. **Firewall rules** (see [architecture.md](../architecture.md), "Firewall intent"). Default deny, then allow only what the design needs.
9. **Verify** (see below), then snapshot both VMs as `01-phase1-done`.

## Verification

- pfSense-A can ping `192.168.20.2`, and pfSense-B can ping `192.168.20.1`.
- A host in the DMZ cannot reach `192.168.11.x` or `192.168.30.x`.
- A host on the attacker network can reach the DMZ but not the transit, SOC, or AD networks.
- Nothing in the lab can reach the home LAN. From any lab VM, `ping` to the home router fails.

## Troubleshooting

- No link on a NIC: confirm the VM's adapter is attached to the right internal network name (exact spelling).
- Windows hypervisor slowdown: expected. Keep each firewall at 1 vCPU and 1 GB RAM.
