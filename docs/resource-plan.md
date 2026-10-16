# Resource plan

Host: Framework laptop with an AMD Ryzen AI 7 350 (8 cores / 16 threads), 64 GB RAM, Windows 11 Pro.

Everything cannot run at once. VMs are started by profile.

## Per-VM sizing

| VM | vCPU | RAM | Disk (max, thin) |
|---|---|---|---|
| pfSense-A | 1 | 1 GB | 16 GB |
| pfSense-B | 1 | 1 GB | 16 GB |
| Domain controller (Server 2022) | 2 | 4 GB | 50 GB |
| Windows client (Win 10/11) | 2 | 4 GB | 50 GB |
| Wazuh all-in-one | 4 | 8 GB | 50 GB |
| Kali | 2 | 4 GB | 40 GB |
| Docker host (DVWA + honeypot) | 2 | 4 GB | 30 GB |
| Splunk | 4 | 8 GB | 50 GB |
| Shuffle (Docker) | 2 | 4 GB | 30 GB |
| Elastic/Kibana (optional) | 4 | 8 GB | 50 GB |

Sizes are starting points and get right-sized during the build.

## Profiles

| Profile | Runs | RAM |
|---|---|---|
| A: Core | pfSense-A, pfSense-B, DC, Windows client, Wazuh | ~22 GB |
| B: Attack | Core + Kali + Docker DMZ host | ~30 GB |
| C: SIEM + SOAR | Core + Splunk + Shuffle | ~38 GB |

All profiles leave 20 GB or more for the host.

## Disk

Thin-provisioned disks only. Provisioned maximums total well above actual use. Check free space after each phase. Snapshots grow quickly, so delete old ones.
