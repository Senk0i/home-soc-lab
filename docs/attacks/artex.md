# Attack scenario 13: LLM-driven pentest with ARTEX against DVWA

**Status:** planned. The tool is installed on Kali and the dual-adapter network setup is in place. The actual run and incident report come later in Phase 5.

## What ARTEX is

[ARTEX](https://github.com/jiwoochris/artex-global) is an open-source "autonomous penetration-testing system" built on an LLM. You give it a target URL and it decides what to probe, how to attack and what to try next, then helps summarise and report. It is included here as one of the Phase 5 attack vectors against the lab's DMZ web app, DVWA.

## Why this is interesting for a SOC lab

- **It is a modern class of attacker.** More testing tools now use an LLM to drive decisions. Seeing what that pattern looks like in logs is useful before meeting it in a real environment.
- **It exercises Wazuh's web detection.** The run should produce a stream of web requests to DVWA that Wazuh can be tuned to detect. Any writing of new Wazuh rules from the results belongs under [detections/](../../detections/).
- **It respects the lab boundary.** The target is DVWA on the isolated DMZ. The attack traffic never leaves the lab.

## Network

ARTEX runs on Kali as a set of Docker containers. For this scenario Kali has two adapters:

| Adapter | Purpose |
|---|---|
| nic1 (NAT) | Only so ARTEX can reach its LLM provider (Anthropic or OpenAI) |
| nic2 (internal `lab-attacker`, address 192.168.1.150/24, gateway 192.168.1.1) | How ARTEX reaches DVWA at `http://192.168.14.10` through the firewalls |

Trade-off: while the NAT adapter is attached, Kali is not fully isolated. It is accepted here because Kali is the attacker, holds no real data, and the window is short. The adapter is removed after the test.

Privacy note: ARTEX sends prompts and target responses to its LLM provider. For a public lab target like DVWA on an isolated network, that is acceptable. Nothing from the SOC side, from AD, from Wazuh or from the host leaves the lab.

## Plan

1. Snapshot Kali and the Docker VM first.
2. In the ARTEX UI, add an Anthropic or OpenAI API key.
3. Point ARTEX at `http://192.168.14.10` (DVWA).
4. Start a short, scoped run (reconnaissance plus a small set of modules).
5. Watch Wazuh. Capture the alerts and the ARTEX run's own report.
6. Write an incident report (`incident-reports/IR-003-artex-dvwa.md`) covering:
   - What ARTEX chose to do, and why
   - Which Wazuh rules fired, and which gaps appeared
   - New or tuned detections to add to `detections/`
   - How much of the activity would be spotted by a stock Wazuh install

## After the run

- Remove the NAT adapter from Kali and re-test that Kali has no internet.
- Keep the ARTEX Docker containers stopped between runs: `docker compose down` in `~/artex-global` on Kali.

## Status log

- Installed on Kali, 2026-10-22, using the project's Docker Compose quick start.
- Admin password set in the UI (lab-only, stored in the local credentials file, not in the repo).
- Pending: dual-adapter setup, the first live run and the incident report.
