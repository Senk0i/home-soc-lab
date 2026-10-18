# Home SOC Lab

A segmented, firewalled home security operations lab built to practice detection engineering, log analysis, and incident response. Attacks are launched from an isolated attacker network, land in a DMZ or on an Active Directory domain, and are detected, investigated, and documented through a SIEM.

## Goals

- Build a realistic multi-zone network (attacker, DMZ, SOC, AD) behind two layered firewalls.
- Collect endpoint and network telemetry in Wazuh and Splunk.
- Run mapped attack scenarios and write custom detections for them (MITRE ATT&CK).
- Automate one response workflow with Shuffle (SOAR).
- Document every attack as an incident report.

## Hardware

The whole lab runs on a single Framework Laptop 13 (AMD Ryzen AI 300 Series): AMD Ryzen AI 7 350 (8 cores / 16 threads), 64 GB RAM, Windows 11 Pro, with VirtualBox as the hypervisor. VMs are started in profiles so the host always keeps 20 GB or more free. See [docs/resource-plan.md](docs/resource-plan.md).

## Architecture

See [docs/architecture.md](docs/architecture.md) for the diagram and IP plan.

| Zone | Subnet | Contents |
|---|---|---|
| Attacker / outside | 192.168.1.0/24 | Kali |
| VPN | 10.0.2.0/24 | OpenVPN (trusted admin path) |
| DMZ | 192.168.14.0/24 | Docker host: DVWA + honeypot |
| Transit | 192.168.20.0/24 | Edge firewall to inner firewall |
| SOC | 192.168.11.0/24 | Wazuh, Shuffle, Splunk, Elastic/Kibana |
| AD | 192.168.30.0/24 | Domain controller + Windows client, Sysmon |

The lab is fully isolated from the host's home network. Nothing is bridged and nothing is port-forwarded.

## Build status

| Phase | Description | Status |
|---|---|---|
| 0 | Host check, repo, resource plan | Done |
| 1 | Virtual networks + pfSense firewalls + Kali | Done |
| 2 | Active Directory + Sysmon | Done |
| 3 | Wazuh SIEM + Sysmon + agents (see [guide](docs/build-guide/phase-3-wazuh-siem.md)) | Working, dashboard check next |
| 4 | Kali + DMZ (DVWA, honeypot) | Not started |
| 5 | First attacks, detections, incident reports | Not started |
| 6 | Splunk | Not started |
| 7 | Shuffle SOAR automation | Not started |
| 8 | OpenVPN admin path (optional Elastic) | Not started |
| 9 | Polish, demo, write-up | Not started |
| 10 | Lab v2: rebuild on Proxmox with infrastructure as code (see [plan](docs/build-guide/phase-10-proxmox-lab-v2.md)) | Planned |

## Repo layout

```
docs/                 architecture, build guide (one file per phase), resource plan
configs/              firewall notes, Wazuh configs, docker-compose files
scripts/              helpers to start/stop VM profiles and take snapshots
detections/           custom Wazuh rules/decoders and Splunk searches
attack-scenarios/     attacks to run, each with its expected detection
incident-reports/     one report per investigated attack (see TEMPLATE.md)
screenshots/          sanitized screenshots only
```

## Detections and reports

Custom detections live in [detections/](detections/). Incident reports live in [incident-reports/](incident-reports/) and follow [TEMPLATE.md](incident-reports/TEMPLATE.md).

## Safety

Lab credentials are intentionally weak and are used only inside the isolated lab networks. They are never stored in this repo. The honeypot and DVWA must never be exposed to a real network.
