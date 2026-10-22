# Next steps

Running list of what to do when the lab is next started.

## 1. A real-time honeypot dashboard in Wazuh (planned)

**Why:** checking alerts with `grep` on the server console works, but it is slow to read and does not show trends. A SOC analyst works in a dashboard.

**What to build** (in the Wazuh dashboard, under Dashboards or Visualize):
- Live alert feed filtered to `rule.groups: honeypot`, auto-refreshing every few seconds
- Alerts over time (line or bar chart), split by rule ID
- Top attacker source addresses
- Count of honeypot logins (rule 100103) as a headline number
- Table of the most recent alerts with time, level, rule description and source address
- Optional MITRE ATT&CK view for the techniques the honeypot rules map to

**How:** the dashboard already ships with Wazuh, so no new software is needed. The honeypot rules tag every alert with the `honeypot` group, which makes the filters simple. Export the finished dashboard as a saved-objects `.ndjson` file into `detections/wazuh/dashboards/` so it can be rebuilt from the repo, and add a sanitized screenshot to `screenshots/`.

**Use it for:** re-running `attack-scenarios/scripts/01-ssh-bruteforce-honeypot.sh` and watching the alerts appear live.

## 2. Finish the honeypot test coverage
- Trigger rule 100110 (brute force) with a longer list of rejected passwords.
- Exercise rules 100104 (command run) and 100105 (file download) with an interactive honeypot session.

## 3. Windows-side detections
Run the Windows attack scenarios from `attack-scenarios/README.md` against `DC01` and `WIN11-CLIENT` and write incident reports.

## 4. ARTEX LLM-driven pentest (scenario 13)
Installed on Kali in a Docker Compose stack. See [docs/attacks/artex.md](attacks/artex.md). Pending: aim it at DVWA, run a scoped test, and write `incident-reports/IR-003-artex-dvwa.md` from the results.

## 5. Housekeeping
- Write `REBUILD.md`, a start-to-finish runbook so the lab can be rebuilt from the repo.
- Add a `lab-start.ps1` and `lab-stop.ps1` for one-command start and shutdown.

## Status when work paused (2026-10-19)

- The honeypot dashboard is generated and ready (`detections/wazuh/dashboards/`) but **not yet imported** into Wazuh. The importer was cancelled at its password prompt.
- To resume: all VMs were saved with VirtualBox "Save state", so starting them restores them exactly as they were. Start order: firewalls, Wazuh, Docker-DMZ, Kali. Check that `wazuh-control status` shows `remoted` and `analysisd` running before trusting alerts.
- Next action: on the Wazuh VM run `sudo mount /dev/sr0 /mnt/tools` (if not mounted) and `bash /mnt/tools/detections/dashboards/import-dashboard.sh`, then open Dashboards > "Honeypot: live attack view".
