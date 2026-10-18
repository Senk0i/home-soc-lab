# Incident Report: Critical "executable dropped" alerts on DC01 (false positive)

| Field | Value |
|---|---|
| Report ID | IR-001 |
| Date | 2026-10-18 (UTC) |
| Analyst | Lab analyst |
| Severity (as alerted) | Critical (rule level 15 or higher) |
| Severity (assessed) | Informational, no impact |
| Status | Closed, false positive, tuning recommended |
| MITRE ATT&CK | Execution: Command and Scripting Interpreter, PowerShell (T1059.001), as the alert was categorised |

## Summary

Four critical Wazuh alerts, "Executable file dropped in folder commonly used by malware", fired on `DC01` within about 8 minutes. Investigation showed that every alert was `powershell.exe` creating a temporary file named `__PSScriptPolicyTest_<random>.ps1` in the Administrator's Temp folder. This is a known benign artifact: PowerShell writes and removes such a file to test how scripts are permitted to run. The activity coincided with lab setup scripts being started on DC01, so the alerts are a false positive.

## Detection

- Source: Wazuh server, Sysmon file-creation events (Sysmon event ID 11) forwarded by the agent on DC01
- Alert: "Executable file dropped in folder commonly used by malware"
- Count: 4, plus 2 high-severity alerts "Sysmon - Suspicious Process - explorer.exe" noted for follow-up (not investigated here)
- Dashboard view: Overview showed 4 critical and 2 high alerts in the last 24 hours, with both agents Active

## Timeline

| Time (UTC) | Event | Host |
|---|---|---|
| 2026-10-18 02:42:10 | `powershell.exe` creates `__PSScriptPolicyTest_*.ps1` in `C:\Users\Administrator\AppData\Local\Temp\` | DC01 |
| 2026-10-18 02:42:32 | Same pattern, second file | DC01 |
| 2026-10-18 02:50:15 | Same pattern, third file | DC01 |
| 2026-10-18 02:50:33 | Same pattern, fourth file | DC01 |

## Evidence

Extracted from `/var/ossec/logs/alerts/alerts.json` on the Wazuh server. For all four alerts:

- Agent: `DC01`
- Process image: `C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe`
- Created file: `C:\Users\Administrator\AppData\Local\Temp\__PSScriptPolicyTest_<random>.ps1`

## Analysis

- **What triggered it:** a rule that looks for script or executable content created in user-writable folders such as Temp, which is a common malware staging pattern.
- **Why it is benign here:** the process is the genuine Windows PowerShell binary under `System32`, the file name is the fixed `__PSScriptPolicyTest_` prefix PowerShell uses to test the script execution policy, the account is the domain Administrator signed in at the console, and the events line up with deliberate lab script runs.
- **What would make it malicious:** a different process (for example a document reader or browser) creating the file, an unusual parent process, a different file name, content that does not match an empty test file, or a follow-up network connection.
- **Verdict:** false positive. No evidence of compromise.

## Impact

None. No data was accessed or changed, and no other host was involved.

## Response

No containment needed. Noted the pattern so it is not mistaken for real activity in later phases.

## Detection improvements

- Tune the detection to ignore file creations whose name starts with `__PSScriptPolicyTest_` when the creating process is `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`. Keep alerting on every other executable or script created in Temp. Rule file to be added under `detections/`.
- Follow up on the two "Sysmon - Suspicious Process - explorer.exe" high-severity alerts.

## Lessons learned

- A SIEM raises alerts on behavior, not intent. Normal administration and attacker behavior can look identical, so analysts verify the process, the path, the account and the timing before escalating.
- Baselining a clean lab early makes real attacks in Phase 5 stand out from this kind of noise.
- Tuning a rule narrowly (one process, one file-name pattern) removes noise without blinding the detection.
