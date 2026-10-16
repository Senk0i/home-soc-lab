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

1. **Get the pfSense ISO.** pfSense CE 2.7.2 (full offline installer) is on Netgate's mirror: `https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz`. Verify it against the `.sha256` file next to it, then extract the `.gz`. Keep the files in this project's git-ignored `isos/` folder so everything stays in one place and nothing large gets committed. The newer 2.8.x line is only distributed through the Netgate Installer store checkout, which downloads packages during install and needs internet.
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

## Progress

| Step | Status |
|---|---|
| Networks and VMs created | Done |
| pfSense-A installed, interfaces and IPs set (WAN 192.168.1.1, DMZ 192.168.14.1, transit 192.168.20.1) | Done, snapshot `01-installed-ips-set` |
| pfSense-B installed, interfaces and IPs set (WAN 192.168.20.2 with gateway 192.168.20.1, SOC 192.168.11.1, AD 192.168.30.1) | Done, snapshot `01-installed-ips-set` |
| Kali installed (2 vCPU, 4 GB), static IP 192.168.1.150/24, gateway 192.168.1.1 | Done |
| Static routes on pfSense-A to SOC and AD via pfSense-B | Done (`configs/pfsense/pfsense-a-baseline.php`) |
| Firewall rules (default deny, DMZ isolation) on both firewalls | Done (`configs/pfsense/pfsense-*-baseline.php`) |
| Verification tests | Done, see results below |
| `02-phase1-baseline` snapshots | Done |

The routes and rules were applied from the firewall consoles with PHP scripts instead of the web UI, so they are reproducible from this repo. `scripts/push-file-to-vm.ps1` types a script into a VM console, with no network needed.

Install notes:
- The installer defaults to ZFS. Use `t`, pick `stripe`, select `ada0` with space, then choose `>>> Install`.
- Power the VM off after the installer says "Complete", eject the ISO while powered off, then boot. Ejecting the ISO from a running installer breaks it.
- The console menu auto-assigns only WAN and LAN. Assign `em2` as OPT1 with option 1.
- By default pfSense blocks inbound traffic on WAN and on new interfaces, so pings between the firewalls fail until rules are added.

## Verification

- pfSense-A can ping `192.168.20.2`, and pfSense-B can ping `192.168.20.1`.
- A host in the DMZ cannot reach `192.168.11.x` or `192.168.30.x`.
- A host on the attacker network can reach the DMZ but not the transit, SOC, or AD networks.
- Nothing in the lab can reach the home LAN. From any lab VM, `ping` to the home router fails.

## Verification results

Run with ICMP echo from Kali. "Blocked" means no reply, as designed. Both firewalls ping each other over the transit network with 0% loss.

| From | Target | Result | Expected |
|---|---|---|---|
| Kali on DMZ (192.168.14.50) | 192.168.14.1 (DMZ firewall) | Reachable | Reachable |
| Kali on DMZ | 192.168.20.1, 192.168.20.2 (transit) | Blocked | Blocked |
| Kali on DMZ | 192.168.11.1 (SOC), 192.168.30.1 (AD) | Blocked | Blocked |
| Kali on attacker net (192.168.1.150) | 192.168.1.1 (edge firewall) | Reachable | Reachable |
| Kali on attacker net | 192.168.14.1 (DMZ) | Reachable | Reachable |
| Kali on attacker net | 192.168.20.1, 192.168.20.2 (transit) | Blocked | Blocked |
| Kali on attacker net | 192.168.11.1 (SOC), 192.168.30.1 (AD) | Blocked | Blocked |
| Kali | 8.8.8.8, home router range, host-only adapter | Blocked | Blocked |
| pfSense-A | 192.168.11.1 (pfSense-B SOC address) | No reply | Blocked by the inner firewall |

All VM network adapters are VirtualBox internal networks only: no bridged, NAT or host-only adapters exist on any lab VM.

Not yet tested, because the hosts do not exist yet: DMZ agent logs to Wazuh (192.168.11.10, ports 1514 to 1515), SOC to DMZ, AD to SOC. Those are checked in Phases 2 to 4.

## Troubleshooting

- No link on a NIC: confirm the VM's adapter is attached to the right internal network name (exact spelling).
- Windows hypervisor slowdown: expected. Keep each firewall at 1 vCPU and 1 GB RAM.
