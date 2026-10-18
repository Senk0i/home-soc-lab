#!/usr/bin/env bash
# Run on the Docker-DMZ VM (Ubuntu Server 24.04) as root, with the LABTOOLS CD mounted.
#
# WHAT: sets the DMZ address, installs Docker from Docker's official apt repository,
#       and starts the lab containers (DVWA, its database, the Cowrie honeypot).
# WHY:  Docker packages each service with everything it needs, so the vulnerable
#       web app and the honeypot start with one command and can be wiped and
#       rebuilt in seconds. That is what makes them good disposable lab targets.
#
# NEEDS: a temporary NAT adapter on the VM (nic2) to download packages and images.
#        Remove it afterwards with scripts/remove-temp-nat.ps1 on the host.
#
# Usage:  sudo mount /dev/sr0 /mnt && sudo bash /mnt/dmz/01-network-and-docker.sh
set -euo pipefail

DMZ_IF="${1:-enp0s3}"      # nic1, lab-dmz (internal, permanent)
NAT_IF="${2:-enp0s8}"      # nic2, NAT (temporary)
SRC="$(cd "$(dirname "$0")" && pwd)"

echo "== Network interfaces =="
ip -br link
echo "Using $DMZ_IF for the DMZ and $NAT_IF for the temporary internet adapter."

echo "== Static DMZ address (no gateway yet; the NAT adapter provides internet for now) =="
cat > /etc/netplan/60-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    $DMZ_IF:
      dhcp4: false
      addresses: [192.168.14.10/24]
    $NAT_IF:
      dhcp4: true
EOF
chmod 600 /etc/netplan/60-lab.yaml
# Ubuntu's installer may have written its own file; ours replaces it.
for f in /etc/netplan/*.yaml; do [ "$f" = /etc/netplan/60-lab.yaml ] || mv "$f" "$f.disabled"; done
netplan apply
sleep 5
ip -br addr show "$DMZ_IF" "$NAT_IF"

echo "== Checking internet access through the temporary adapter =="
curl -fsS --max-time 15 -o /dev/null https://download.docker.com/linux/ubuntu/gpg && echo "internet OK"

echo "== Installing Docker Engine and Compose from Docker's official repository =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "== Starting the DMZ services =="
mkdir -p /opt/dmz
cp "$SRC/../configs/dmz/docker-compose.yml" /opt/dmz/docker-compose.yml 2>/dev/null \
  || cp "$SRC/docker-compose.yml" /opt/dmz/docker-compose.yml
cd /opt/dmz
docker compose pull
docker compose up -d
sleep 20
docker compose ps
echo "Done. Next: sudo bash $SRC/02-wazuh-agent.sh"
