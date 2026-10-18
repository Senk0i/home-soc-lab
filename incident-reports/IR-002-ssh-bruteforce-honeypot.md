# Incident Report: SSH brute force against the DMZ honeypot

| Field | Value |
|---|---|
| Report ID | IR-002 |
| Date | 2026-10-18 (UTC) |
| Analyst | Lab analyst |
| Severity | High (a login to the honeypot succeeded; no real asset affected) |
| Status | Closed. Simulated attack in an isolated lab, detections validated. |
| MITRE ATT&CK | T1046 Network Service Discovery, T1110 Brute Force, T1078 Valid Accounts |

## Summary

From the lab's attacker host (Kali, 192.168.1.150), a port scan and a password-guessing run were launched against the Cowrie SSH honeypot on the DMZ host (192.168.14.10). The Wazuh SIEM raised 9 honeypot alerts within about 3 seconds: 5 new-connection alerts, 2 failed-login alerts and 2 successful-login alerts. This was a controlled test of the custom detection rules in `detections/wazuh/cowrie_rules.xml`.

## Detection

- **Source:** Cowrie JSON event log shipped by the Wazuh agent on `Docker-DMZ`, decoded by Wazuh's JSON decoder and matched by custom rules.
- **Attacker address:** 192.168.1.150 on every alert.

| Rule | Level | Count | Description |
|---|---|---|---|
| 100101 | 5 | 5 | Honeypot: new SSH connection |
| 100102 | 7 | 2 | Honeypot: failed SSH login for user 'root' |
| 100103 | 10 | 2 | Honeypot: attacker logged in as 'root' |

## Timeline

| Time (UTC) | Event |
|---|---|
| 05:33:55 | Port scan reaches the DMZ host: SSH (22) and HTTP (80) open, MySQL (3306) closed |
| 05:33:56 | Five connections to the honeypot (rule 100101) |
| 05:33:58 | Two failed logins for `root` (rule 100102) |
| 05:33:58 | Two logins accepted by the honeypot (rule 100103) |

## Evidence

- `screenshots/kali-attack-terminal.png`: the attacker's view (scan results, Hydra finding 2 valid passwords)
- `screenshots/wazuh-honeypot-alert-summary.png`: alert counts by type
- `screenshots/wazuh-honeypot-alert-detail.png`: one line per alert with time, level, description and source

## Analysis

- The honeypot has no legitimate users, so every connection is suspicious. That is why the rules score it higher than an ordinary server login.
- The attacker found two accepted logins out of ten guesses. Cowrie accepts weak guesses on purpose, to keep an attacker engaged and recording what they do next.
- The progression is the classic chain: discover the service (T1046), guess credentials (T1110), obtain a working login (T1078).

## What did NOT fire, and why

- **Rule 100110 (5 failed logins in 60 seconds, brute force):** did not fire. Only 2 guesses failed, because the honeypot accepted most of them. The rule needs five failures from one address, so a wordlist of mostly weak, accepted guesses never reaches the threshold. This is a limitation of the test data, not a fault in the rule. A follow-up test with a longer list of rejected passwords would exercise it.
- **Rules 100104 (command run) and 100105 (file download):** not exercised. The attack stopped at login and no shell session was opened. These were validated offline only.

## Impact

None. The honeypot is isolated and holds no real data. No other host was involved.

## Response

No containment needed in the lab. In a real environment: block the source address, review any other hosts the same address touched, and hunt for the same sequence elsewhere.

## Detection improvements

- Add a test with more rejected passwords to prove rule 100110 fires.
- Open an interactive session on the honeypot to exercise rules 100104 and 100105.
- Consider a rule that links "successful honeypot login" to later commands from the same session.

## Lessons learned

- A SIEM collecting logs is not the same as a SIEM alerting. Cowrie's events were collected for a whole session before any alert existed, until the decoder-based rules were written.
- Prove a rule offline first (`wazuh-logtest`), then with live traffic. When live traffic and a rule disagree, the test data is as likely to be the cause as the rule.
- After restarting the lab, confirm `wazuh-remoted` is running before trusting any result.
