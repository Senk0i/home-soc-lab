# Detections

Custom detection content for the lab's Wazuh SIEM. Each detection documents what it looks for, why it matters, how it was tested, and which MITRE ATT&CK technique it maps to.

## Cowrie honeypot rules

File: [`wazuh/cowrie_rules.xml`](wazuh/cowrie_rules.xml), rule IDs 100100 and up.

**Why these exist.** The Cowrie honeypot on `Docker-DMZ` writes one JSON line per event. The Wazuh agent ships those lines to the server and its built-in JSON decoder splits them into fields, but Wazuh's default ruleset has no rules for those fields. Without custom rules the events are stored and never raise an alert.

**Why severity is raised.** Nothing legitimate ever talks to a honeypot, so any connection is suspicious and anything that logs in or types a command is hostile by definition.

| Rule | Level | Fires on | ATT&CK |
|---|---|---|---|
| 100100 | 0 | Any Cowrie event (anchor for the rules below, never alerts itself) | n/a |
| 100101 | 5 | New connection to the fake SSH port | T1046 Network Service Discovery |
| 100102 | 7 | Failed login attempt | T1110 Brute Force |
| 100103 | 10 | Login the honeypot accepted | T1078 Valid Accounts, T1110 |
| 100104 | 12 | Command typed in the fake shell | T1059.004 Unix Shell |
| 100105 | 13 | Attempt to download a file or payload | T1105 Ingress Tool Transfer |
| 100110 | 10 | 5 failed logins from one address within 60 seconds | T1110 Brute Force |

### How it was tested

1. **Syntax:** `wazuh-analysisd -t` on the Wazuh server returned success, so the server accepted the rule file.
2. **Rule logic, offline:** a fabricated Cowrie `cowrie.login.failed` event was fed to `wazuh-logtest`. It matched **rule 100102 at level 7**, with the description "Honeypot: failed SSH login for user 'root' from 192.168.1.150", mapped to Credential Access / Brute Force (T1110), and reported that an alert would be generated.
3. **Live traffic:** the brute-force scenario (`attack-scenarios/scripts/01-ssh-bruteforce-honeypot.sh`) produced 9 alerts from rules 100101, 100102 and 100103. Rule 100110 did not fire because only 2 guesses failed, and rules 100104 and 100105 were not exercised. See [IR-002](../incident-reports/IR-002-ssh-bruteforce-honeypot.md).

### Installing

Copy `cowrie_rules.xml` to `/var/ossec/etc/rules/` on the Wazuh server, run `/var/ossec/bin/wazuh-analysisd -t`, then `sudo systemctl restart wazuh-manager`. After a restart, confirm `wazuh-remoted` is running before trusting the SIEM.
