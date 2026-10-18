#!/usr/bin/env bash
# Run on the Docker-DMZ VM as root, while the temporary NAT adapter is still attached.
#
# WHAT: installs the Wazuh agent, points it at the Wazuh server (192.168.11.10),
#       and tells it to read the honeypot's JSON event log and Docker's logs.
# WHY:  the honeypot records every login attempt and command an attacker types.
#       The agent ships those records to the SIEM, so attacks on the DMZ show up
#       as alerts next to everything else.
#
# Usage:  sudo bash /mnt/dmz/02-wazuh-agent.sh
set -euo pipefail

MANAGER="${1:-192.168.11.10}"
VERSION="4.14.9-1"
DEB="wazuh-agent_${VERSION}_amd64.deb"

export DEBIAN_FRONTEND=noninteractive
cd /tmp
curl -fsSL -o "$DEB" "https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/$DEB"
WAZUH_MANAGER="$MANAGER" WAZUH_AGENT_NAME="DOCKER-DMZ" dpkg -i "./$DEB"

COWRIE_LOG="$(docker volume inspect dmz_cowrie-log --format '{{ .Mountpoint }}' 2>/dev/null || true)/cowrie.json"
CONF=/var/ossec/etc/ossec.conf
if ! grep -q 'cowrie.json' "$CONF"; then
  python3 - "$CONF" "$COWRIE_LOG" <<'PY'
import sys
conf, log = sys.argv[1], sys.argv[2]
text = open(conf).read()
block = f"""
  <!-- Honeypot events (Cowrie) -->
  <localfile>
    <log_format>json</log_format>
    <location>{log}</location>
  </localfile>

</ossec_config>"""
i = text.rindex("</ossec_config>")
open(conf, "w").write(text[:i] + block + "\n")
PY
  echo "Added the honeypot log: $COWRIE_LOG"
fi

systemctl daemon-reload
systemctl enable --now wazuh-agent
sleep 5
systemctl --no-pager status wazuh-agent | head -5
tail -5 /var/ossec/logs/ossec.log
