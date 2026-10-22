# Attack scenarios

Run each scenario only inside the isolated lab. Snapshot the target first. For each one, record the expected detection, then the actual result in an incident report.

| # | Scenario | ATT&CK | Target | Expected detection | Status |
|---|---|---|---|---|---|
| 1 | SSH brute force against the honeypot | T1046, T1110 | DMZ honeypot | Rules 100101 to 100103 | Run, see [IR-002](../incident-reports/IR-002-ssh-bruteforce-honeypot.md) |
| 2 | Encoded PowerShell execution | T1059.001 | Windows client | Sysmon event 1 + custom rule | Planned |
| 3 | Scheduled task persistence | T1053.005 | Windows client | Sysmon / Windows event 4698 | Planned |
| 4 | Credential dumping (LSASS access) | T1003.001 | Windows client | Sysmon event 10 | Planned |
| 5 | Web attack on DVWA (SQLi) | T1190 | DMZ Docker host | Web log + Wazuh rule | Planned |
| 6 | Account discovery and AD enumeration | T1087 | Domain controller | Windows security events | Planned |
| 7 | Lateral movement (pass-the-hash or PsExec) | T1021 | AD hosts | Windows events 4624/4648, Sysmon | Planned |
| 8 | Honeypot interaction and port scan | T1046 | DMZ | Honeypot logs + firewall logs | Planned |
| 9 | New local admin account | T1136.001 | Windows client | Windows event 4720/4732 | Planned |
| 10 | Log clearing | T1070.001 | Windows client | Event 1102 | Planned |
| 11 | Longer SSH brute force (triggers the volume rule) | T1110 | DMZ honeypot | Honeypot rule 100110 (5 failures in 60 seconds) | Planned |
| 12 | Interactive honeypot session (commands and downloads) | T1059.004, T1105 | DMZ honeypot | Honeypot rules 100104, 100105 | Planned |
| 13 | LLM-driven pentest run with ARTEX against DVWA | T1595, T1190 | DMZ web app | DVWA access logs (Wazuh), plus honeypot rules if ARTEX probes SSH | Planned, see [docs/attacks/artex.md](../docs/attacks/artex.md) |
