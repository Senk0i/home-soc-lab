# Phase 3: Wazuh SIEM, Sysmon and agents

Goal: a working detection pipeline. Endpoint activity is recorded by Sysmon, shipped by the Wazuh agent across the inner firewall, and analyzed by the Wazuh server, which raises alerts you can investigate.

## What each piece does, and why

| Piece | Where | Purpose |
|---|---|---|
| **Sysmon** | DC01, WIN11-CLIENT | Records what normal Windows logs leave out: every process started (with parent and command line), network connections, file and registry changes. Most attack techniques show up as unusual processes and connections, so this is the raw evidence. |
| **Wazuh agent** | DC01, WIN11-CLIENT | A small service that reads Windows event logs, including the Sysmon channel, and sends them to the server over TCP 1514. First-time enrolment uses TCP 1515. |
| **Wazuh server** | `Wazuh` VM, 192.168.11.10 on the SOC network | Receives the logs, applies detection rules, stores events and raises alerts, with a web dashboard. |

Flow: `Sysmon -> Windows event log -> Wazuh agent -> pfSense-B -> Wazuh server -> rules -> alert`

This is the first time the Phase 1 firewall design carries real traffic: the AD zone may reach the SOC zone for agent traffic, and the DMZ may reach only Wazuh on 1514 to 1515.

## Design

| Item | Value |
|---|---|
| Wazuh version | 4.14.9 (OVA, Amazon Linux 2023) |
| Wazuh VM | 2 vCPU, 8 GB RAM, 50 GB disk, on `lab-soc` only, static 192.168.11.10/24, gateway 192.168.11.1 |
| Agents | DC01 (ID 001), WIN11-CLIENT (ID 002) |
| Sysmon | 15.22 with the SwiftOnSecurity configuration |

## Steps

1. **Download on the host** (the lab has no internet): the Wazuh OVA, the Wazuh agent MSI, `Sysmon.zip` and the SwiftOnSecurity `sysmonconfig-export.xml`. Verify them: the OVA against Wazuh's published SHA-512, the MSI and Sysmon against their Authenticode signatures. Keep them in the git-ignored `isos/` and `tools/` folders.
2. **Import the Wazuh OVA** with `VBoxManage import`, then switch its adapter from Bridged to the internal network `lab-soc` **before first boot**, so it can never reach the home network. Set the graphics controller to VMSVGA and the clock to UTC, as Wazuh recommends.
3. **Set the static address.** On this image networking is handled by `systemd-networkd`: replace `/etc/systemd/network/20-eth0.network` with the static address and restart `systemd-networkd`.
4. **Build the tools CD** with `scripts/make-tools-iso.ps1` and attach it to both Windows VMs. It carries the scripts, Sysmon and the Wazuh agent.
5. **Install the Wazuh agent** on each Windows VM: `scripts/ad/05-install-wazuh-agent.ps1`. It also adds the Sysmon event channel to the agent configuration.
6. **Install Sysmon** on each Windows VM: `scripts/ad/04-install-sysmon.ps1`.
7. **Verify** (below), then snapshot.

## Verification results

| Check | Result |
|---|---|
| Wazuh services (manager, indexer, dashboard, filebeat) | All active |
| Listening ports on the server | 1514, 1515, 443, 55000, 9200 (indexer on localhost only) |
| DC01 reaches 192.168.11.10 port 1515 across pfSense-B | True |
| `agent_control -l` on the server | DC01 Active, WIN11-CLIENT Active |
| Sysmon service on both Windows machines | Running, driver `SysmonDrv` loaded |
| Sysmon events in Wazuh alerts | 41 alerts matched on "sysmon" shortly after enabling it |
| Wazuh VM adapters | Internal network `lab-soc` only |

### A detection of our own setup

One alert fired 12 times: rule 92205, level 9, "Powershell process created an executable file in Windows root folder" (MITRE T1105, Ingress Tool Transfer). That is exactly what installing Sysmon looks like from the outside: a PowerShell session copying an executable into `C:\Windows`. The same behavior is a classic way attackers drop tools, which is why the rule exists. Legitimate admin activity and attacker activity can look the same, and a SOC analyst's job is to tell them apart using context.

## Lessons learned

- **A failed first Sysmon install leaves a read-only copy of `Sysmon64.exe` in `C:\Windows`** and no service. Every retry then fails with "Error copying sysmon in systemroot: Access is denied". Deleting that file and running the install again succeeds. The script now removes such a stale copy automatically and runs from a local folder.
- **Run installers from a local folder, not the CD.**
- **Restart the Wazuh agent after Sysmon is installed** so it starts reading the Sysmon channel.
- **The Wazuh image ships with public default passwords** (VM `wazuh-user`, dashboard `admin`). Change them before relying on the lab.
- **Idle VMs lock their screens.** Send Ctrl+Alt+Del and type promptly.

## Still to do

- Change the default Wazuh passwords.
- Open the dashboard (`https://192.168.11.10`) from a lab machine and take a sanitized screenshot for the repo.
- Snapshot the Wazuh VM and the Windows machines.
- Phase 5 uses this pipeline to detect real attacks.

## Lab convenience: auto sign-in and no idle lock (lab only)

Idle VMs lock their screens, and a locked console blocks any scripted or demo work. `scripts/ad/06-lab-autologon.ps1` fixes that on a lab machine:

- Turns on Windows' built-in `AutoAdminLogon`, so the VM signs itself in at boot.
- Disables the idle lock, screen saver lock and the sign-in prompt on wake.
- Asks for the password twice at run time and refuses a mismatch. The password is never passed on a command line or stored in the repo.

Trade-off, stated plainly: Windows keeps the password in the registry in plain text for this feature. That is acceptable only on a throwaway, isolated lab VM with no real data, and must never be used on a real or internet-connected machine. `-Remove` undoes the auto sign-in.

Tested: after running it on DC01 and restarting, the server signed itself in and reached the desktop with no input.
