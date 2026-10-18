# Phase 4: DMZ targets (DVWA and a honeypot)

Goal: put deliberately attackable systems in the DMZ, so the attacker network has something to attack and the SIEM has something to detect.

## What each piece does, and why

| Piece | Where | Purpose |
|---|---|---|
| **DVWA** (Damn Vulnerable Web Application) | Docker on `Docker-DMZ`, port 80 | A web app with real, intentional vulnerabilities (SQL injection, command injection, file upload, brute force). Practise attacks safely and watch what they look like in logs. |
| **MariaDB** | Docker, internal only | DVWA's database. Not published outside the container. |
| **Cowrie** | Docker, port 22 | An SSH honeypot: a fake SSH server that accepts almost any login and records every command the "attacker" types. Port 22 is published so scanners find it. The host has no real SSH server on purpose. |
| **Wazuh agent** | `Docker-DMZ` | Ships the host's logs and the honeypot's JSON event log to the Wazuh server. |

Why Docker: each service ships with everything it needs, starts with one command and can be wiped and rebuilt in seconds, which suits disposable lab targets.

## Design

| Item | Value |
|---|---|
| VM | `Docker-DMZ`, Ubuntu Server 24.04.4 LTS, 4 GB RAM, 30 GB disk, installed on 1 vCPU |
| Network | `lab-dmz` only, 192.168.14.10/24, gateway 192.168.14.1 (pfSense-A) |
| Firewall | Phase 1 rules already allow the attacker network to reach the DMZ and the DMZ agent to reach Wazuh on 1514 and 1515, while blocking the DMZ from SOC, AD and transit |

## Steps

1. **Download** `ubuntu-24.04.4-live-server-amd64.iso` and verify it against Ubuntu's `SHA256SUMS`.
2. **Create the VM** with `scripts/phase4-create-docker-vm.ps1`. It adds a *temporary* NAT adapter (nic2), used only to download Docker and the images.
3. **Install Ubuntu Server.** Do not install OpenSSH: the honeypot owns port 22.
4. **Install Docker and start the services** with `scripts/dmz/01-network-and-docker.sh` (uses `configs/dmz/docker-compose.yml`).
5. **Install the Wazuh agent** with `scripts/dmz/02-wazuh-agent.sh`. It also adds the honeypot's `cowrie.json` to the agent configuration.
6. **Finalize isolation** with `scripts/dmz/03-finalize-isolated.sh`, shut the VM down, then run `scripts/remove-temp-nat.ps1 -Vm Docker-DMZ`. It removes the NAT adapter and verifies that only internal networks remain.

## Safety notes

- The only time any lab VM had internet access was this one VM during step 2 to 5. It was removed and verified before anything vulnerable was reachable.
- DVWA and Cowrie must never be exposed to a real network. The VM's only adapter is the internal `lab-dmz` network.
- The credentials in `docker-compose.yml` are DVWA's own published demo defaults, not personal credentials.
- Cowrie runs unprivileged inside its container and has no real shell.

## Lessons learned

- `ip addr show` takes a single device: pass one adapter, or omit it.
- Quote characters get mangled when commands are typed into a console, so scripts delivered on a CD are more reliable than commands typed one line at a time.
- A VM console screen that looks logged in may still be at `login:`. Check for the shell prompt before sending commands.
