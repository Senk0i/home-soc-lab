# Honeypot dashboard

A real-time Wazuh dashboard for the Cowrie honeypot, kept as code.

| File | Purpose |
|---|---|
| `build-honeypot-dashboard.ps1` | Generates the dashboard definition |
| `honeypot-dashboard.ndjson` | The generated saved objects (import this file) |
| `import-dashboard.sh` | Imports the file on the Wazuh server; asks for the password at a hidden prompt |

## What it shows

- **Attackers who logged in:** headline counter (rule 100103)
- **Alerts over time by rule:** one line per honeypot rule, so a scan or brute force shows as a spike
- **Top attacker addresses**
- **Alerts by description:** which behaviours occurred and how often
- **Alert feed:** the newest honeypot alerts with level, rule, description, source address and agent

It refreshes every 5 seconds over the last hour. All panels filter on the `honeypot` rule group set by `../cowrie_rules.xml`, so it only shows honeypot activity.

## Use it

1. Regenerate (optional): `.\build-honeypot-dashboard.ps1`
2. Make the file available on the Wazuh server (the lab's tools CD carries it under `detections/dashboards/`).
3. On the Wazuh server: `sudo mount /dev/sr0 /mnt/tools`, then `bash /mnt/tools/detections/dashboards/import-dashboard.sh`.
4. In the Wazuh dashboard, open **Dashboards** and choose **Honeypot: live attack view**.
5. Run `attack-scenarios/scripts/01-ssh-bruteforce-honeypot.sh` from Kali and watch the panels update.
